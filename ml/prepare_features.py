# ml/prepare_features.py
import os
import pandas as pd
from sqlalchemy import create_engine
from dotenv import load_dotenv
from datetime import timedelta

load_dotenv()

engine = create_engine(
    f"postgresql+psycopg2://{os.getenv('POSTGRES_USER')}:{os.getenv('POSTGRES_PASSWORD')}@"
    f"{os.getenv('POSTGRES_HOST')}:{os.getenv('POSTGRES_PORT')}/{os.getenv('POSTGRES_DB')}"
)

DATA_DIR = "./data"
os.makedirs(DATA_DIR, exist_ok=True)

def load_weather_data():
    print("📥 Lecture des données météo depuis PostgreSQL...")
    query = """
        SELECT lat, lon, observation_time, temp_c, humidity, precipitation_mm, wind_speed, pressure
        FROM weather_observations
        WHERE temp_c IS NOT NULL AND humidity IS NOT NULL;
    """
    df = pd.read_sql(query, engine)
    df.sort_values(by=["lat", "lon", "observation_time"], inplace=True)
    print(f"✅ {len(df)} enregistrements récupérés.")
    return df


def engineer_features(df):
    print("🧠 Feature engineering en cours...")
    df["hour"] = df["observation_time"].dt.hour
    df["day"] = df["observation_time"].dt.day
    df["month"] = df["observation_time"].dt.month

    df["temp_rolling_mean"] = df.groupby(["lat", "lon"])["temp_c"].transform(lambda x: x.rolling(6, min_periods=1).mean())
    df["humidity_rolling_mean"] = df.groupby(["lat", "lon"])["humidity"].transform(lambda x: x.rolling(6, min_periods=1).mean())
    df["precip_rolling_sum"] = df.groupby(["lat", "lon"])["precipitation_mm"].transform(lambda x: x.rolling(6, min_periods=1).sum())
    df["wind_rolling_mean"] = df.groupby(["lat", "lon"])["wind_speed"].transform(lambda x: x.rolling(6, min_periods=1).mean())

    print("✅ Feature engineering terminé.")
    return df


def create_datasets(df):
    print("🪄 Création des datasets ML...")

    # ---  Prédiction de pluie ---
    rain_df = df.copy()
    rain_df["rain_next_hour"] = rain_df.groupby(["lat", "lon"])["precipitation_mm"].shift(-1)
    rain_df["rain_label"] = (rain_df["rain_next_hour"] > 0.2).astype(int)
    rain_df.dropna(subset=["rain_label"], inplace=True)
    rain_df.to_csv(os.path.join(DATA_DIR, "rain_dataset.csv"), index=False)
    print(f"✅ rain_dataset.csv enregistré ({len(rain_df)} lignes).")

    # ---  Prédiction de sécheresse ---
    drought_df = df.copy()
    drought_df["cum_rain_3days"] = (
        drought_df.groupby(["lat", "lon"])["precipitation_mm"]
        .transform(lambda x: x.rolling(72, min_periods=1).sum())
    )
    drought_df["drought_label"] = (drought_df["cum_rain_3days"] < 1.0).astype(int)
    drought_df.to_csv(os.path.join(DATA_DIR, "drought_dataset.csv"), index=False)
    print(f"✅ drought_dataset.csv enregistré ({len(drought_df)} lignes).")

    # --- Prédiction de maladies ---
    disease_df = df.copy()
    disease_df["disease_risk"] = (
        (disease_df["humidity_rolling_mean"] > 85) &
        (disease_df["temp_rolling_mean"].between(25, 35))
    ).astype(int)
    disease_df.to_csv(os.path.join(DATA_DIR, "disease_dataset.csv"), index=False)
    print(f"✅ disease_dataset.csv enregistré ({len(disease_df)} lignes).")

    return rain_df, drought_df, disease_df


def main():
    df = load_weather_data()
    df = engineer_features(df)
    create_datasets(df)
    print("🎉 Tous les datasets ML ont été générés avec succès !")


if __name__ == "__main__":
    main()
