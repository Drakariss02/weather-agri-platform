from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import joblib, pandas as pd, numpy as np, requests, os
from datetime import datetime

router = APIRouter()

MODEL_PATH = os.path.join("../ml/artifacts", "disease_model.pkl")
model = joblib.load(MODEL_PATH)

class DiseaseForecastInput(BaseModel):
    lat: float
    lon: float

def fetch_openmeteo_forecast(lat: float, lon: float):
    """Récupère les prévisions météo Open-Meteo (3 jours)"""
    url = (
        "https://api.open-meteo.com/v1/forecast?"
        f"latitude={lat}&longitude={lon}"
        "&hourly=temperature_2m,relative_humidity_2m,precipitation,"
        "wind_speed_10m,pressure_msl&forecast_days=3&timezone=Africa%2FDakar"
    )
    response = requests.get(url, timeout=30)
    response.raise_for_status()
    data = response.json()

    df = pd.DataFrame({
        "observation_time": data["hourly"]["time"],
        "temp_c": data["hourly"]["temperature_2m"],
        "humidity": data["hourly"]["relative_humidity_2m"],
        "precipitation_mm": data["hourly"]["precipitation"],
        "wind_speed": data["hourly"]["wind_speed_10m"],
        "pressure": data["hourly"]["pressure_msl"],
    })
    df["lat"], df["lon"] = lat, lon
    df["observation_time"] = pd.to_datetime(df["observation_time"])
    df["hour"] = df["observation_time"].dt.hour
    df["day"] = df["observation_time"].dt.day
    df["month"] = df["observation_time"].dt.month

    # Variables de tendance
    df["temp_rolling_mean"] = df["temp_c"].rolling(3, min_periods=1).mean()
    df["humidity_rolling_mean"] = df["humidity"].rolling(3, min_periods=1).mean()
    df["precip_rolling_sum"] = df["precipitation_mm"].rolling(3, min_periods=1).sum()
    df["wind_rolling_mean"] = df["wind_speed"].rolling(3, min_periods=1).mean()

    return df

@router.post("/forecast")
def predict_disease_forecast(data: DiseaseForecastInput):
    """Prédit le risque de maladie sur 3 jours à partir des prévisions Open-Meteo"""
    try:
        df = fetch_openmeteo_forecast(data.lat, data.lon)
        
        expected_cols = [
            "lat", "lon", "temp_c", "humidity", "precipitation_mm", 
            "wind_speed", "pressure", "hour", "day", "month",
            "temp_rolling_mean", "humidity_rolling_mean", 
            "precip_rolling_sum", "wind_rolling_mean"
        ]
        
        missing_features = set(expected_cols) - set(df.columns)
        if missing_features:
            print(f"❌ Features manquantes: {missing_features}")
            raise HTTPException(status_code=500, detail=f"Features manquantes: {missing_features}")
        
        df_features = df[expected_cols]
        
        print("🔍 Features utilisées pour la prédiction:", df_features.columns.tolist())
        print("🔍 Shape des données:", df_features.shape)
        
        print("=== DIAGNOSTIC MODÈLE ===")
        print(f"Type: {type(model)}")
        print(f"n_features_in_: {getattr(model, 'n_features_in_', 'N/A')}")
        if hasattr(model, 'feature_names_in_'):
            print(f"Features attendues: {model.feature_names_in_.tolist()}")
        else:
            print("Aucun feature_names_in_ disponible")
        
        preds = model.predict(df_features)
        
        if hasattr(model, "predict_proba"):
            probs = model.predict_proba(df_features)[:, 1]
        else:
            probs = preds
        
        df["disease_label"] = preds
        df["disease_prob"] = probs
        
        df["date"] = pd.to_datetime(df["observation_time"]).dt.date
        forecast = (
            df.groupby("date")
              .agg(disease_risk=("disease_prob", "mean"), disease_alert=("disease_label", "max"))
              .reset_index()
        )

        result = {
            "location": {"lat": data.lat, "lon": data.lon},
            "forecast_days": len(forecast),
            "predictions": [
                {
                    "date": row["date"].strftime("%Y-%m-%d"),
                    "disease_risk": round(row["disease_risk"], 2),
                    "disease_alert": bool(row["disease_alert"])
                }
                for _, row in forecast.iterrows()
            ]
        }

        return result
        
    except Exception as e:
        print(f"❌ Erreur lors de la prédiction: {e}")
        raise HTTPException(status_code=500, detail=f"Erreur de prédiction: {str(e)}")