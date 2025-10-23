# routers/irrigation.py
from fastapi import APIRouter
from pydantic import BaseModel
import joblib, pandas as pd, os, numpy as np

router = APIRouter()
MODEL_PATH = os.path.join("../ml/artifacts", "irrigation_model.pkl")
model = joblib.load(MODEL_PATH)

class IrrigationInput(BaseModel):
    lat: float
    lon: float
    temp_c: float
    humidity: float
    precipitation_mm: float
    wind_speed: float
    pressure: float
    hour: int
    day: int
    month: int
    temp_rolling_mean: float
    humidity_rolling_mean: float
    precip_rolling_sum: float
    wind_rolling_mean: float
    cum_rain_3days: float

@router.post("/")
def predict_irrigation(data: IrrigationInput):
    et0 = 0.0023 * (data.temp_c + 17.8) * (data.wind_speed / 10)

    df = pd.DataFrame([{
        "lat": data.lat,
        "lon": data.lon,
        "temp_c": data.temp_c,
        "humidity": data.humidity,
        "precipitation_mm": data.precipitation_mm,
        "wind_speed": data.wind_speed,
        "pressure": data.pressure,
        "hour": data.hour,
        "day": data.day,
        "month": data.month,
        "temp_rolling_mean": data.temp_rolling_mean,
        "humidity_rolling_mean": data.humidity_rolling_mean,
        "precip_rolling_sum": data.precip_rolling_sum,
        "wind_rolling_mean": data.wind_rolling_mean,
        "et0": et0,
        "cum_rain_3days": data.cum_rain_3days
    }])

    pred = model.predict(df)[0]

    return {
        "water_need_estimated": round(float(pred), 2),
        "et0_computed": round(float(et0), 3)
    }
