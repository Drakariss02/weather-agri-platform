from fastapi import APIRouter
from pydantic import BaseModel
import joblib, pandas as pd, numpy as np, requests, os
from datetime import datetime

router = APIRouter()

#MODEL_PATH = os.path.join("../ml/artifacts", "rain_model.pkl")

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.path.join(BASE_DIR, "../models/rain_model.pkl")

model = joblib.load(MODEL_PATH)

class RainForecastInput(BaseModel):
    lat: float
    lon: float

def add_cyclical_features(df):
    df["sin_hour"] = np.sin(2 * np.pi * df["hour"] / 24)
    df["cos_hour"] = np.cos(2 * np.pi * df["hour"] / 24)
    df["sin_month"] = np.sin(2 * np.pi * df["month"] / 12)
    df["cos_month"] = np.cos(2 * np.pi * df["month"] / 12)
    return df

def fetch_openmeteo_forecast(lat: float, lon: float):
    url = (
        "https://api.open-meteo.com/v1/forecast?"
        f"latitude={lat}&longitude={lon}"
        "&hourly=temperature_2m,relative_humidity_2m,precipitation,wind_speed_10m,pressure_msl"
        "&forecast_days=3&timezone=Africa%2FDakar"
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
        "pressure": data["hourly"]["pressure_msl"]
    })
    df["lat"], df["lon"] = lat, lon
    df["observation_time"] = pd.to_datetime(df["observation_time"])
    df["hour"] = df["observation_time"].dt.hour
    df["day"] = df["observation_time"].dt.day
    df["month"] = df["observation_time"].dt.month

    # Ajout des variables de tendance (rolling windows)
    df["temp_rolling_mean"] = df["temp_c"].rolling(window=3, min_periods=1).mean()
    df["humidity_rolling_mean"] = df["humidity"].rolling(window=3, min_periods=1).mean()
    df["precip_rolling_sum"] = df["precipitation_mm"].rolling(window=3, min_periods=1).sum()
    df["wind_rolling_mean"] = df["wind_speed"].rolling(window=3, min_periods=1).mean()

    return df

@router.post("/forecast")
def predict_rain_forecast(data: RainForecastInput):
    df = fetch_openmeteo_forecast(data.lat, data.lon)

    df = add_cyclical_features(df)

    expected_features = model.get_booster().feature_names
    print("Features attendues par le modèle (ordre exact):", expected_features)
    
    df_features = df[expected_features]
    print("Features utilisées pour la prédiction (après réordre):", df_features.columns.tolist())

    if list(df_features.columns) != expected_features:
        print("ATTENTION: L'ordre des features ne correspond pas!")
        df_features = df_features[expected_features]

    preds = model.predict(df_features)
    
    if hasattr(model, "predict_proba"):
        rain_probs = model.predict_proba(df_features)[:, 1]
    else:
        rain_probs = preds  

    df["rain_label"] = preds
    df["rain_prob"] = rain_probs

    df["date"] = pd.to_datetime(df["observation_time"]).dt.date
    forecast = (
        df.groupby("date")
          .agg(rain_risk=("rain_prob", "mean"), rain_label=("rain_label", "max"))
          .reset_index()
    )

    result = {
        "location": {"lat": data.lat, "lon": data.lon},
        "forecast_days": len(forecast),
        "predictions": [
            {
                "date": row["date"].strftime("%Y-%m-%d"),
                "rain_risk": round(row["rain_risk"], 2),
                "rain_expected": bool(row["rain_label"])
            }
            for _, row in forecast.iterrows()
        ]
    }

    return result