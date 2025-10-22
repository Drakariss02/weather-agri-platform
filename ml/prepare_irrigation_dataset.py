import os
import pandas as pd
import numpy as np
from sqlalchemy import create_engine
from dotenv import load_dotenv

load_dotenv()

PG_HOST = os.getenv("POSTGRES_HOST", "localhost")
PG_PORT = os.getenv("POSTGRES_PORT", "5432")
PG_DB = os.getenv("POSTGRES_DB", "agri")
PG_USER = os.getenv("POSTGRES_USER", "agri_user")
PG_PASS = os.getenv("POSTGRES_PASSWORD", "changeme")

DATABASE_URL = f"postgresql://{PG_USER}:{PG_PASS}@{PG_HOST}:{PG_PORT}/{PG_DB}"

DATA_DIR = "./data"
os.makedirs(DATA_DIR, exist_ok=True)

def load_weather_data():
    try:
        engine = create_engine(DATABASE_URL)
        query = "SELECT lat, lon, observation_time, temp_c, humidity, precipitation_mm, wind_speed, pressure FROM weather_observations;"
        df = pd.read_sql(query, engine)
        print(f"✅ {len(df)} enregistrements chargés depuis PostgreSQL")
    except Exception as e:
        print(f"⚠️ Impossible de charger depuis PostgreSQL ({e}), lecture JSON locale...")
        dfs = []
        for file in os.listdir(DATA_DIR):
            if file.startswith("openmeteo_") and file.endswith(".json"):
                fpath = os.path.join(DATA_DIR, file)
                print(f"→ Lecture : {fpath}")
                data = pd.read_json(fpath)
                hourly = pd.DataFrame(data["hourly"])
                hourly["lat"] = data["latitude"]
                hourly["lon"] = data["longitude"]
                dfs.append(hourly)
        df = pd.concat(dfs, ignore_index=True)
    return df


def prepare_irrigation_features(df: pd.DataFrame):
    df["observation_time"] = pd.to_datetime(df["observation_time"])
    df["hour"] = df["observation_time"].dt.hour
    df["day"] = df["observation_time"].dt.day
    df["month"] = df["observation_time"].dt.month

    df["temp_rolling_mean"] = df["temp_c"].rolling(3, min_periods=1).mean()
    df["humidity_rolling_mean"] = df["humidity"].rolling(3, min_periods=1).mean()
    df["precip_rolling_sum"] = df["precipitation_mm"].rolling(6, min_periods=1).sum()
    df["wind_rolling_mean"] = df["wind_speed"].rolling(3, min_periods=1).mean()

    df["et0"] = 0.0023 * np.sqrt(np.maximum(df["temp_c"].rolling(3).max() - df["temp_c"].rolling(3).min(), 0)) * (df["temp_c"] + 17.8)
    df["et0"].fillna(df["et0"].mean(), inplace=True)

    df["cum_rain_3days"] = df["precipitation_mm"].rolling(72, min_periods=1).sum()

    df["water_need"] = (df["et0"] * (1 + (df["wind_speed"] / 10))) - df["precip_rolling_sum"]
    df["water_need"] = df["water_need"].clip(lower=0)

    def irrigation_level(need):
        if need < 2:
            return "low"
        elif need < 5:
            return "medium"
        else:
            return "high"

    df["irrigation_label"] = df["water_need"].apply(irrigation_level)

    return df


def main():
    df = load_weather_data()
    df = prepare_irrigation_features(df)

    output_path = os.path.join(DATA_DIR, "irrigation_dataset.csv")
    df.to_csv(output_path, index=False)
    print(f"💾 Dataset irrigation sauvegardé : {output_path}")
    print(df[["observation_time", "temp_c", "humidity", "precipitation_mm", "water_need", "irrigation_label"]].head())


if __name__ == "__main__":
    main()
