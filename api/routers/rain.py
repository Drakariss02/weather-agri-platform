# routers/rain.py
from fastapi import APIRouter
from pydantic import BaseModel
import joblib, pandas as pd, os
import numpy as np

router = APIRouter()

MODEL_PATH = os.path.join("../ml/artifacts", "rain_model.pkl")
model = joblib.load(MODEL_PATH)

class RainInput(BaseModel):
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

def add_cyclical_features(df):
    """Ajoute les features cycliques pour hour et month"""
    df['sin_hour'] = np.sin(2 * np.pi * df['hour'] / 24)
    df['cos_hour'] = np.cos(2 * np.pi * df['hour'] / 24)
    df['sin_month'] = np.sin(2 * np.pi * df['month'] / 12)
    df['cos_month'] = np.cos(2 * np.pi * df['month'] / 12)
    return df

@router.post("/")
def predict_rain(data: RainInput):
    df = pd.DataFrame([data.dict()])
    
    df = add_cyclical_features(df)
    
    expected_features = ['lat', 'lon', 'temp_c', 'humidity', 'precipitation_mm', 
                        'wind_speed', 'pressure', 'hour', 'day', 'month', 
                        'temp_rolling_mean', 'humidity_rolling_mean', 
                        'precip_rolling_sum', 'wind_rolling_mean', 
                        'sin_hour', 'cos_hour', 'sin_month', 'cos_month']
    
    df = df[expected_features]
    
    pred = model.predict(df)[0]
    
    if hasattr(model, "predict_proba"):
        prob = float(model.predict_proba(df)[0][1])  
    else:
        prob = None
    
    return {
        "rain_label": int(pred),  
        "rain_probability": round(prob, 3) if prob is not None else None
    }