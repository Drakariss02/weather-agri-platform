# etl/load.py
import os
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

load_dotenv()
PG_HOST = os.environ.get("POSTGRES_HOST", "postgres")
PG_PORT = os.environ.get("POSTGRES_PORT", "5432")
PG_DB = os.environ.get("POSTGRES_DB", "agri")
PG_USER = os.environ.get("POSTGRES_USER", "agri_user")
PG_PASS = os.environ.get("POSTGRES_PASSWORD", "changeme")


DATABASE_URL = f"postgresql://{PG_USER}:{PG_PASS}@{PG_HOST}:{PG_PORT}/{PG_DB}"
engine = create_engine(DATABASE_URL, pool_size=5, max_overflow=10)

def bulk_insert_weather(records, batch_size=200):
    if not records:
        return 0
    inserted = 0
    insert_sql = text("""
      INSERT INTO weather_observations
        (lat, lon, observation_time, temp_c, humidity, precipitation_mm, wind_speed, pressure, raw)
      VALUES
        (:lat, :lon, :observation_time, :temp_c, :humidity, :precipitation_mm, :wind_speed, :pressure, :raw)
    """)
    with engine.begin() as conn:
        for i in range(0, len(records), batch_size):
            batch = records[i:i+batch_size]
            conn.execute(insert_sql, batch)
            inserted += len(batch)
    try:
        with engine.begin() as conn:
            conn.execute(text("""
                INSERT INTO etl_runs(source, rows_extracted, rows_loaded, status, log)
                VALUES (:src, :ext, :lod, :status, :log)
            """), {"src": "openmeteo", "ext": len(records), "lod": inserted, "status": "success", "log": "bulk insert ok"})
    except Exception:
        pass
    return inserted
