import os
import psycopg2
from psycopg2.extras import execute_values
from datetime import datetime
from dotenv import load_dotenv

load_dotenv()

class DataLoader:
    def __init__(self):
        self.connection = None
        self.connect()
    
    def connect(self):
        """Connexion à PostgreSQL"""
        try:
            self.connection = psycopg2.connect(
                host=os.getenv('DB_HOST', 'localhost'),
                port=os.getenv('DB_PORT', '5432'),
                database=os.getenv('DB_NAME', 'weather_agri_db'),
                user=os.getenv('DB_USER', 'postgres'),
                password=os.getenv('DB_PASSWORD')
            )
            print("✓ Connexion PostgreSQL établie")
        except Exception as e:
            print(f"✗ Erreur de connexion PostgreSQL: {e}")
            raise
    
    def load_observations(self, observations):
        """Charge les observations dans PostgreSQL"""
        if not observations:
            print("⚠️  Aucune observation à charger")
            return 0
        
        try:
            cursor = self.connection.cursor()
            
            query = """
                INSERT INTO observations 
                (location, timestamp, temperature, humidity, pressure, 
                 wind_speed, wind_direction, weather_description)
                VALUES %s
                ON CONFLICT (location, timestamp) DO UPDATE SET
                    temperature = EXCLUDED.temperature,
                    humidity = EXCLUDED.humidity,
                    pressure = EXCLUDED.pressure,
                    wind_speed = EXCLUDED.wind_speed,
                    wind_direction = EXCLUDED.wind_direction,
                    weather_description = EXCLUDED.weather_description
            """
            
            values = [
                (
                    obs['location'],
                    obs['timestamp'],
                    obs.get('temperature'),
                    obs.get('humidity'),
                    obs.get('pressure'),
                    obs.get('wind_speed'),
                    obs.get('wind_direction'),
                    obs.get('weather_description')
                )
                for obs in observations
            ]
            
            execute_values(cursor, query, values)
            self.connection.commit()
            
            print(f"✓ {len(observations)} observations chargées dans PostgreSQL")
            cursor.close()
            return len(observations)
            
        except Exception as e:
            self.connection.rollback()
            print(f"✗ Erreur chargement observations: {e}")
            return 0
    
    def load_forecasts(self, forecasts):
        """Charge les prévisions dans PostgreSQL"""
        if not forecasts:
            print("⚠️  Aucune prévision à charger")
            return 0
        
        try:
            cursor = self.connection.cursor()
            
            query = """
                INSERT INTO forecasts 
                (location, forecast_timestamp, temperature, temperature_min, 
                 temperature_max, humidity, pressure, wind_speed, 
                 weather_description, precipitation_probability)
                VALUES %s
                ON CONFLICT (location, forecast_timestamp) DO UPDATE SET
                    temperature = EXCLUDED.temperature,
                    temperature_min = EXCLUDED.temperature_min,
                    temperature_max = EXCLUDED.temperature_max,
                    humidity = EXCLUDED.humidity,
                    pressure = EXCLUDED.pressure,
                    wind_speed = EXCLUDED.wind_speed,
                    weather_description = EXCLUDED.weather_description,
                    precipitation_probability = EXCLUDED.precipitation_probability
            """
            
            values = [
                (
                    fc['location'],
                    fc['forecast_timestamp'],
                    fc.get('temperature'),
                    fc.get('temperature_min'),
                    fc.get('temperature_max'),
                    fc.get('humidity'),
                    fc.get('pressure'),
                    fc.get('wind_speed'),
                    fc.get('weather_description'),
                    fc.get('precipitation_probability')
                )
                for fc in forecasts
            ]
            
            execute_values(cursor, query, values)
            self.connection.commit()
            
            print(f"✓ {len(forecasts)} prévisions chargées dans PostgreSQL")
            cursor.close()
            return len(forecasts)
            
        except Exception as e:
            self.connection.rollback()
            print(f"✗ Erreur chargement prévisions: {e}")
            return 0
    
    def load_quality_report(self, quality_report):
        """Charge le rapport de qualité dans PostgreSQL"""
        try:
            cursor = self.connection.cursor()
            
            # Rapport pour les observations
            if quality_report['observations']['total'] > 0:
                cursor.execute("""
                    INSERT INTO quality_reports 
                    (table_name, total_records, valid_records, invalid_records, 
                     completeness_rate, issues_found)
                    VALUES (%s, %s, %s, %s, %s, %s)
                """, (
                    'observations',
                    quality_report['observations']['total'],
                    quality_report['observations']['valid'],
                    quality_report['observations']['invalid'],
                    quality_report['observations']['completeness_rate'],
                    '\n'.join(quality_report['observations']['issues'][:10])
                ))
            
            # Rapport pour les prévisions
            if quality_report['forecasts']['total'] > 0:
                cursor.execute("""
                    INSERT INTO quality_reports 
                    (table_name, total_records, valid_records, invalid_records, 
                     completeness_rate, issues_found)
                    VALUES (%s, %s, %s, %s, %s, %s)
                """, (
                    'forecasts',
                    quality_report['forecasts']['total'],
                    quality_report['forecasts']['valid'],
                    quality_report['forecasts']['invalid'],
                    quality_report['forecasts']['completeness_rate'],
                    '\n'.join(quality_report['forecasts']['issues'][:10])
                ))
            
            self.connection.commit()
            print("✓ Rapports de qualité chargés dans PostgreSQL")
            cursor.close()
            
        except Exception as e:
            self.connection.rollback()
            print(f"✗ Erreur chargement rapports qualité: {e}")
    
    def get_statistics(self):
        """Récupère les statistiques de la base de données"""
        try:
            cursor = self.connection.cursor()
            
            stats = {}
            
            # Nombre d'observations
            cursor.execute("SELECT COUNT(*) FROM observations")
            stats['observations_count'] = cursor.fetchone()[0]
            
            # Nombre de prévisions
            cursor.execute("SELECT COUNT(*) FROM forecasts")
            stats['forecasts_count'] = cursor.fetchone()[0]
            
            # Nombre de rapports qualité
            cursor.execute("SELECT COUNT(*) FROM quality_reports")
            stats['quality_reports_count'] = cursor.fetchone()[0]
            
            # Localités couvertes
            cursor.execute("SELECT DISTINCT location FROM observations ORDER BY location")
            stats['locations'] = [row[0] for row in cursor.fetchall()]
            
            cursor.close()
            return stats
            
        except Exception as e:
            print(f"✗ Erreur récupération statistiques: {e}")
            return {}
    
    def print_statistics(self):
        """Affiche les statistiques de la base"""
        stats = self.get_statistics()
        
        print("\n" + "=" * 60)
        print("📊 STATISTIQUES BASE DE DONNÉES")
        print("=" * 60)
        print(f"Observations: {stats.get('observations_count', 0)}")
        print(f"Prévisions: {stats.get('forecasts_count', 0)}")
        print(f"Rapports qualité: {stats.get('quality_reports_count', 0)}")
        print(f"Localités: {', '.join(stats.get('locations', []))}")
        print("=" * 60 + "\n")
    
    def close(self):
        """Ferme la connexion"""
        if self.connection:
            self.connection.close()
            print("✓ Connexion PostgreSQL fermée")