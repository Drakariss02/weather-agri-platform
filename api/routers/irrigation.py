from fastapi import APIRouter
from pydantic import BaseModel
import pandas as pd
import numpy as np
import joblib, os, requests

router = APIRouter()

MODEL_PATH = os.path.join("../ml/artifacts", "irrigation_model1.pkl")
model = joblib.load(MODEL_PATH)


class IrrigationForecastInput(BaseModel):
    lat: float
    lon: float


def calculate_realistic_et0(df: pd.DataFrame) -> pd.Series:
    Tmax = df["temp_c"].rolling(24, min_periods=1).max()
    Tmin = df["temp_c"].rolling(24, min_periods=1).min()
    deltaT = np.maximum(Tmax - Tmin, 5)

    # Facteur saisonnier 
    seasonal_factor = df["month"].map({
        11: 4.4, 12: 4.4, 1: 4.4, 2: 4.3, 3: 4.2, 4: 4.1,
        5: 5.0, 6: 2.9, 7: 2.9, 8: 2.9, 9: 3.0, 10: 3.2
    }).fillna(1.0)

    et0 = (
        0.0028 * (df["temp_c"] + 18)
        * np.sqrt(deltaT)
        * (1 + df["wind_speed"] / 15)
        * (1.5 - df["humidity"] / 100)
        * seasonal_factor
    )

    return et0.clip(1.0, 7.0).fillna(3.5)


def fetch_openmeteo_forecast(lat: float, lon: float) -> pd.DataFrame:
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
        "pressure": data["hourly"]["pressure_msl"]
    })

    df["lat"], df["lon"] = lat, lon
    df["observation_time"] = pd.to_datetime(df["observation_time"])
    df["hour"] = df["observation_time"].dt.hour
    df["day"] = df["observation_time"].dt.day
    df["month"] = df["observation_time"].dt.month

    # === Variables de tendance ===
    df["temp_rolling_mean"] = df["temp_c"].rolling(3, min_periods=1).mean()
    df["humidity_rolling_mean"] = df["humidity"].rolling(3, min_periods=1).mean()
    df["precip_rolling_sum"] = df["precipitation_mm"].rolling(6, min_periods=1).sum()
    df["wind_rolling_mean"] = df["wind_speed"].rolling(3, min_periods=1).mean()
    df["cum_rain_3days"] = df["precipitation_mm"].rolling(72, min_periods=1).sum()

    # === Calcul ET₀ ===
    df["et0"] = calculate_realistic_et0(df)

    print("✅ Données météo récupérées depuis Open-Meteo")
    return df


@router.post("/forecast")
def predict_irrigation_forecast(data: IrrigationForecastInput):
    try:
        df = fetch_openmeteo_forecast(data.lat, data.lon)

        print(f"🌍 Coordonnées: {data.lat}, {data.lon}")
        print(f"Température moyenne: {df['temp_c'].mean():.1f}°C")
        print(f"Humidité moyenne: {df['humidity'].mean():.1f}%")
        print(f"Vent moyen: {df['wind_speed'].mean():.1f} m/s")
        print(f"ET0 moyenne: {df['et0'].mean():.2f} mm/jour")

        features = [
            "lat", "lon", "temp_c", "humidity", "precipitation_mm", "wind_speed",
            "pressure", "hour", "day", "month",
            "temp_rolling_mean", "humidity_rolling_mean",
            "precip_rolling_sum", "wind_rolling_mean", "et0", "cum_rain_3days"
        ]

        df_features = df[features]

        preds = model.predict(df_features)
        df["predicted_water_need"] = preds
        df["date"] = df["observation_time"].dt.date

        forecast = (
            df.groupby("date")
              .agg(
                  water_need=("predicted_water_need", "mean"),
                  rain=("precipitation_mm", "mean"),
                  et0_day=("et0", "mean")
              )
              .reset_index()
        )

        def get_recommendation(need):
            if need < 2:
                return "✅ Sol bien humide - pas d’irrigation nécessaire"
            elif need < 4:
                return "💧 Besoin léger - irrigation courte (1-2h)"
            elif need < 6:
                return "💧💧 Besoin modéré - irrigation normale (2-3h)"
            elif need < 8:
                return "💧💧💧 Besoin élevé - irrigation prolongée (3-4h)"
            else:
                return "🚿 BESOIN URGENT - irrigation intensive (4h+)"

        result = {
            "location": {"lat": data.lat, "lon": data.lon},
            "forecast_days": len(forecast),
            "predictions": [
                {
                    "date": row["date"].strftime("%Y-%m-%d"),
                    "water_need_mm": round(row["water_need"], 2),
                    "rain_mm": round(row["rain"], 2),
                    "et0_mm": round(row["et0_day"], 2),
                    "recommendation": get_recommendation(row["water_need"])
                }
                for _, row in forecast.iterrows()
            ]
        }

        print("✅ Prévision irrigation générée avec succès")
        return result

    except Exception as e:
        print(f"❌ Erreur dans /forecast: {e}")
        raise
