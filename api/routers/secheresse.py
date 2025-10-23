# routers/secheresse.py
from fastapi import APIRouter
from pydantic import BaseModel
import joblib, pandas as pd, os

router = APIRouter()
MODEL_PATH = os.path.join("../ml/artifacts", "secheresse_model.pkl")
model = joblib.load(MODEL_PATH)

class DroughtInput(BaseModel):
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
def predict_drought(data: DroughtInput):
    df = pd.DataFrame([data.dict()])
    pred = model.predict(df)[0]
    return {"drought_label": int(pred)}
