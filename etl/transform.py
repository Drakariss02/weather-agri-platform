# etl/transform_openmeteo.py
import json
from datetime import datetime, timezone

def transform_openmeteo_to_records(json_file_path):
    with open(json_file_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    lat, lon = data["latitude"], data["longitude"]
    hourly = data["hourly"]
    records = []

    for i in range(len(hourly["time"])):
        time_str = hourly["time"][i]
        obs_time = datetime.fromisoformat(time_str)
        if obs_time.tzinfo is None:
            obs_time = obs_time.replace(tzinfo=timezone.utc)

        rec = {
            "lat": lat,
            "lon": lon,
            "observation_time": obs_time,
            "temp_c": hourly.get("temperature_2m", [None])[i],
            "humidity": hourly.get("relative_humidity_2m", [None])[i],
            "precipitation_mm": hourly.get("precipitation", [None])[i],
            "wind_speed": hourly.get("wind_speed_10m", [None])[i],
            "pressure": hourly.get("pressure_msl", [None])[i],
            "raw": json.dumps({k: hourly[k][i] for k in hourly}),
        }
        records.append(rec)

    print(f"✅ {len(records)} enregistrements transformés (Open-Meteo)")
    return records

if __name__ == "__main__":
    transform_openmeteo_to_records("./data/openmeteo_Notto-Diobass_2022_2024.json")
