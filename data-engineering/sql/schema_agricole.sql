-- Tables agricoles pour enrichir le projet

-- Table des cultures
CREATE TABLE IF NOT EXISTS crops (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    optimal_temp_min FLOAT,        -- Température minimale optimale (°C)
    optimal_temp_max FLOAT,        -- Température maximale optimale (°C)
    water_need_daily FLOAT,        -- Besoin en eau quotidien (mm)
    growth_duration_days INTEGER,  -- Durée de croissance (jours)
    humidity_optimal FLOAT,        -- Humidité optimale (%)
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table des champs agricoles
CREATE TABLE IF NOT EXISTS fields (
    id SERIAL PRIMARY KEY,
    field_name VARCHAR(100) NOT NULL,
    location VARCHAR(100) NOT NULL,
    latitude FLOAT,
    longitude FLOAT,
    area_hectares FLOAT,           -- Surface en hectares
    soil_type VARCHAR(50),          -- Type de sol
    crop_id INTEGER REFERENCES crops(id),
    planting_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table des recommandations agricoles
CREATE TABLE IF NOT EXISTS agricultural_recommendations (
    id SERIAL PRIMARY KEY,
    field_id INTEGER REFERENCES fields(id),
    recommendation_date TIMESTAMP NOT NULL,
    temperature FLOAT,
    humidity FLOAT,
    precipitation_forecast FLOAT,
    
    -- Recommandations calculées
    irrigation_needed BOOLEAN,
    irrigation_amount_mm FLOAT,
    risk_level VARCHAR(20),         -- low, medium, high
    risk_type VARCHAR(50),          -- drought, excess_rain, disease, etc.
    action_recommended TEXT,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insertion de cultures typiques du Sénégal
INSERT INTO crops (name, optimal_temp_min, optimal_temp_max, water_need_daily, growth_duration_days, humidity_optimal, description)
VALUES 
    ('Mil', 20, 35, 3.5, 90, 60, 'Céréale résistante à la sécheresse, culture principale au Sénégal'),
    ('Arachide', 22, 30, 4.0, 120, 65, 'Culture de rente importante, besoin hydrique modéré'),
    ('Maïs', 18, 32, 5.0, 100, 70, 'Céréale à fort besoin hydrique'),
    ('Riz', 20, 35, 7.0, 120, 80, 'Culture irriguée, fort besoin en eau'),
    ('Niébé', 20, 35, 3.0, 75, 60, 'Légumineuse résistante, bonne pour rotation'),
    ('Manioc', 25, 35, 4.5, 300, 75, 'Tubercule résistant, croissance longue'),
    ('Tomate', 18, 27, 5.0, 90, 65, 'Maraîchage, sensible aux variations');

-- Insertion de champs de démonstration
INSERT INTO fields (field_name, location, latitude, longitude, area_hectares, soil_type, crop_id, planting_date)
VALUES 
    ('Champ Nord Dakar', 'Dakar', 14.7167, -17.4677, 2.5, 'Sableux', 1, CURRENT_DATE - INTERVAL '30 days'),
    ('Parcelle Saint-Louis', 'Saint-Louis', 16.0330, -16.5080, 5.0, 'Argileux', 3, CURRENT_DATE - INTERVAL '45 days'),
    ('Exploitation Kaolack', 'Kaolack', 14.1522, -16.0770, 10.0, 'Limono-sableux', 2, CURRENT_DATE - INTERVAL '60 days');

-- Index pour les performances
CREATE INDEX IF NOT EXISTS idx_fields_location ON fields(location);
CREATE INDEX IF NOT EXISTS idx_agricultural_recommendations_date ON agricultural_recommendations(recommendation_date);
CREATE INDEX IF NOT EXISTS idx_agricultural_recommendations_field ON agricultural_recommendations(field_id);