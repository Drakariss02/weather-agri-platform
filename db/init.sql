-- db/init.sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS farms (
  id SERIAL PRIMARY KEY,
  name TEXT,
  owner TEXT,
  lat DOUBLE PRECISION NOT NULL,
  lon DOUBLE PRECISION NOT NULL,
  crop_type TEXT,
  area_ha DOUBLE PRECISION,
  contact_phone TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS weather_observations (
  id SERIAL PRIMARY KEY,
  farm_id INTEGER REFERENCES farms(id) ON DELETE SET NULL,
  lat DOUBLE PRECISION NOT NULL,
  lon DOUBLE PRECISION NOT NULL,
  observation_time TIMESTAMPTZ NOT NULL,
  temp_c DOUBLE PRECISION,
  humidity DOUBLE PRECISION,
  precipitation_mm DOUBLE PRECISION,
  wind_speed DOUBLE PRECISION,
  pressure DOUBLE PRECISION,
  raw JSONB,
  inserted_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_weather_obs_time ON weather_observations (observation_time);
CREATE INDEX IF NOT EXISTS idx_weather_obs_location ON weather_observations (lat, lon);

CREATE TABLE IF NOT EXISTS etl_runs (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  run_time TIMESTAMPTZ DEFAULT now(),
  source TEXT,
  rows_extracted INTEGER,
  rows_loaded INTEGER,
  status TEXT,
  log TEXT
);
