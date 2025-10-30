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

    Tmax = df["temp_c"].rolling(24, min_periods=1).max()
    Tmin = df["temp_c"].rolling(24, min_periods=1).min()
    deltaT = np.maximum(Tmax - Tmin, 5)

    seasonal_factor = df["month"].map({
        11: 4.4, 12: 4.4, 1: 4.4, 2: 4.3, 3: 4.2, 4: 4.1,
        5: 5.0, 6: 2.9, 7: 2.9, 8: 2.9, 9: 3.0, 10: 3.2
    }).fillna(1.0)

    df["et0"] = (
        0.0028 * (df["temp_c"] + 18) * np.sqrt(deltaT)
        * (1 + df["wind_speed"] / 15)
        * (1.5 - df["humidity"] / 100)
        * seasonal_factor
    )
    df["et0"] = df["et0"].clip(1.0, 7.0).fillna(3.5)

    df["cum_rain_3days"] = df["precipitation_mm"].rolling(72, min_periods=1).sum()

    effective_rain = df["precip_rolling_sum"] * 0.7
    df["water_need"] = (df["et0"] - effective_rain).clip(lower=0.3)

    df.loc[df["month"].isin([3, 4, 5]), "water_need"] *= 3.3  # plus chaud → besoin ↑
    df.loc[df["month"].isin([7, 8, 9]), "water_need"] *= 2.8  # pluies → besoin ↓

    df["water_need"] = df["water_need"].clip(0.3, 9.0)

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
