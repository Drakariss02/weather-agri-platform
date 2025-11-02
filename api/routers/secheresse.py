from fastapi import APIRouter
from pydantic import BaseModel
import joblib, pandas as pd, numpy as np, requests, os
from datetime import datetime

router = APIRouter()

MODEL_PATH = os.path.join("../ml/artifacts", "secheresse_model.pkl")
model = joblib.load(MODEL_PATH)

class DroughtForecastInput(BaseModel):
    lat: float
    lon: float

def fetch_openmeteo_forecast(lat: float, lon: float):
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

    df["cum_rain_3days"] = df["precipitation_mm"].rolling(72, min_periods=1).sum()

    return df

@router.post("/forecast")
def predict_drought_forecast(data: DroughtForecastInput):
    df = fetch_openmeteo_forecast(data.lat, data.lon)
    
    dates = df["observation_time"].copy()
    
    expected_cols = [
        "lat","lon","temp_c","humidity","precipitation_mm",
        "wind_speed","pressure","hour","day","month",
        "temp_rolling_mean","humidity_rolling_mean","precip_rolling_sum",
        "wind_rolling_mean","cum_rain_3days"
    ]
    
    df_features = df[expected_cols]

    preds = model.predict(df_features)
    probs = model.predict_proba(df_features)[:, 1] if hasattr(model, "predict_proba") else preds

    df["drought_label"] = preds
    df["drought_prob"] = probs
    
    df["date"] = pd.to_datetime(dates).dt.date

    forecast = (
        df.groupby("date")
          .agg(drought_risk=("drought_prob", "mean"), drought_alert=("drought_label", "max"))
          .reset_index()
    )

    result = {
        "location": {"lat": data.lat, "lon": data.lon},
        "forecast_days": len(forecast),
        "predictions": [
            {
                "date": row["date"].strftime("%Y-%m-%d"),
                "drought_risk": round(row["drought_risk"], 2),
                "drought_alert": bool(row["drought_alert"])
            }
            for _, row in forecast.iterrows()
        ]
    }

    return result