-- TABLE 1: Observations météo actuelles
CREATE TABLE weather_observations (
    id SERIAL PRIMARY KEY,
    location_name VARCHAR(100),
    latitude DECIMAL(10, 6),
    longitude DECIMAL(10, 6),
    timestamp TIMESTAMPTZ,
    temperature_celsius DECIMAL(5, 2),
    humidity_percent DECIMAL(5, 2),
    precipitation_mm DECIMAL(8, 2),
    wind_speed_kmh DECIMAL(5, 2),
    weather_condition VARCHAR(50),
    data_source VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- TABLE 2: Prévisions météo
CREATE TABLE weather_forecasts (
    id SERIAL PRIMARY KEY,
    location_name VARCHAR(100),
    latitude DECIMAL(10, 6),
    longitude DECIMAL(10, 6),
    forecast_date DATE,
    forecast_hour INT,
    temperature_celsius DECIMAL(5, 2),
    humidity_percent DECIMAL(5, 2),
    precipitation_probability DECIMAL(5, 2),
    precipitation_expected_mm DECIMAL(8, 2),
    wind_speed_kmh DECIMAL(5, 2),
    weather_condition VARCHAR(50),
    model_name VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- TABLE 3: Rapports qualité
CREATE TABLE data_quality_logs (
    id SERIAL PRIMARY KEY,
    table_name VARCHAR(50),
    record_count INT,
    null_count INT,
    quality_score DECIMAL(5, 2),
    status VARCHAR(20),
    checked_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- INDEXES pour la performance
CREATE INDEX idx_weather_obs ON weather_observations(location_name, timestamp DESC);
CREATE INDEX idx_forecast ON weather_forecasts(forecast_date);