# etl/run_etl_openmeteo.py
import os
from fetch_openmeteo import fetch_historical
from transform import transform_openmeteo_to_records
from load import bulk_insert_weather
from dotenv import load_dotenv

load_dotenv()

def main():
    LOCATIONS = [
        {"name": "Notto-Diobass", "lat": 14.7210, "lon": -16.8882},
        {"name": "Richard-Toll", "lat": 16.4590, "lon": -15.6926},
        {"name": "Nioro-du-Rip", "lat": 13.7453, "lon": -15.7743}
    ]

    for loc in LOCATIONS:
        print(f"🌍 Récupération météo pour {loc['name']}...")
        file_path = fetch_historical(loc)
        records = transform_openmeteo_to_records(file_path)
        inserted = bulk_insert_weather(records)
        print(f"✅ {inserted} lignes insérées pour {loc['name']}.\n")

if __name__ == "__main__":
    main()
