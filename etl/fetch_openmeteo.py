# etl/fetch_openmeteo.py
import os
import json
import requests
from datetime import date

DATA_DIR = os.environ.get("DATA_DIR", "./data")
os.makedirs(DATA_DIR, exist_ok=True)

REGIONS = [
    #{"name": "Diouroup", "lat": 14.3709, "lon": -16.5286},
    {"name": "Notto-Diobass", "lat": 14.7210, "lon": -16.8882},
    {"name": "Richard-Toll", "lat": 16.4590, "lon": -15.6926},
    {"name": "Nioro-du-Rip", "lat": 13.7453, "lon": -15.7743},
    #{"name": "Dakar", "lat": 14.6928, "lon": -17.4467},
    #{"name": "Thiès", "lat": 14.783, "lon": -16.924},
    #{"name": "Diourbel", "lat": 14.655, "lon": -16.233},
    #{"name": "Kaolack", "lat": 14.146, "lon": -16.070},
    #{"name": "Fatick", "lat": 14.345, "lon": -16.410},
    #{"name": "Kaffrine", "lat": 13.983, "lon": -15.533},
    #{"name": "Louga", "lat": 15.611, "lon": -16.224},
    #{"name": "Saint-Louis", "lat": 16.017, "lon": -16.489},
    #{"name": "Matam", "lat": 15.616, "lon": -13.255},
    #{"name": "Tambacounda", "lat": 13.770, "lon": -13.667},
    #{"name": "Kédougou", "lat": 12.555, "lon": -12.184},
    #{"name": "Sédhiou", "lat": 12.708, "lon": -15.556},
    #{"name": "Kolda", "lat": 12.883, "lon": -14.950},
    #{"name": "Ziguinchor", "lat": 12.583, "lon": -16.271},
]

START_DATE = "2022-01-01"
END_DATE = "2024-12-31"

def fetch_historical(region):
    url = (
        "https://archive-api.open-meteo.com/v1/archive?"
        f"latitude={region['lat']}&longitude={region['lon']}"
        f"&start_date={START_DATE}&end_date={END_DATE}"
        "&hourly=temperature_2m,relative_humidity_2m,precipitation,"
        "wind_speed_10m,pressure_msl"
        "&timezone=Africa/Dakar"
    )
    print(f"🌍 Téléchargement historique pour {region['name']}...")

    response = requests.get(url, timeout=120)
    response.raise_for_status()
    data = response.json()

    safe_name = region["name"].replace(" ", "_").replace("’", "").replace("'", "")
    output_file = os.path.join(DATA_DIR, f"openmeteo_{safe_name}_2022_2024.json")

    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print(f"✅ Données sauvegardées : {output_file}")
    return output_file

def main():
    for region in REGIONS:
        try:
            fetch_historical(region)
        except Exception as e:
            print(f"❌ Erreur pour {region['name']}: {e}")

if __name__ == "__main__":
    main()
