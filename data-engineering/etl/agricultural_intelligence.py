"""
Module d'intelligence agricole
Génère des recommandations basées sur la météo et les cultures
"""

import psycopg2
from datetime import datetime, timedelta
import os
from dotenv import load_dotenv

load_dotenv()

class AgriculturalIntelligence:
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
            print("✓ Connexion PostgreSQL établie (Agricultural Intelligence)")
        except Exception as e:
            print(f"✗ Erreur de connexion: {e}")
            raise
    
    def get_field_with_crop(self, field_id):
        """Récupère un champ avec sa culture"""
        cursor = self.connection.cursor()
        
        query = """
            SELECT f.field_name, f.location, f.area_hectares, f.soil_type, f.planting_date,
                   c.name, c.optimal_temp_min, c.optimal_temp_max, 
                   c.water_need_daily, c.growth_duration_days, c.humidity_optimal
            FROM fields f
            JOIN crops c ON f.crop_id = c.id
            WHERE f.id = %s
        """
        
        cursor.execute(query, (field_id,))
        result = cursor.fetchone()
        cursor.close()
        
        if result:
            return {
                'field_name': result[0],
                'location': result[1],
                'area_hectares': result[2],
                'soil_type': result[3],
                'planting_date': result[4],
                'crop_name': result[5],
                'optimal_temp_min': result[6],
                'optimal_temp_max': result[7],
                'water_need_daily': result[8],
                'growth_duration_days': result[9],
                'humidity_optimal': result[10]
            }
        return None
    
    def get_latest_weather(self, location):
        """Récupère la météo la plus récente pour une localité"""
        cursor = self.connection.cursor()
        
        query = """
            SELECT temperature, humidity, pressure, wind_speed, weather_description, timestamp
            FROM observations
            WHERE location = %s
            ORDER BY timestamp DESC
            LIMIT 1
        """
        
        cursor.execute(query, (location,))
        result = cursor.fetchone()
        cursor.close()
        
        if result:
            return {
                'temperature': result[0],
                'humidity': result[1],
                'pressure': result[2],
                'wind_speed': result[3],
                'description': result[4],
                'timestamp': result[5]
            }
        return None
    
    def get_forecast_precipitation(self, location, days=3):
        """Récupère les prévisions de précipitation"""
        cursor = self.connection.cursor()
        
        query = """
            SELECT SUM(precipitation_probability) / COUNT(*) as avg_precipitation,
                   MAX(precipitation_probability) as max_precipitation
            FROM forecasts
            WHERE location = %s 
            AND forecast_timestamp BETWEEN NOW() AND NOW() + INTERVAL '%s days'
        """
        
        cursor.execute(query, (location, days))
        result = cursor.fetchone()
        cursor.close()
        
        return {
            'avg_precipitation_probability': result[0] if result[0] else 0,
            'max_precipitation_probability': result[1] if result[1] else 0
        }
    
    def calculate_water_stress(self, field_data, weather_data, precipitation_forecast):
        """Calcule le stress hydrique"""
        # Facteurs de stress
        temperature_stress = 0
        humidity_stress = 0
        precipitation_stress = 0
        
        # Stress température
        if weather_data['temperature'] > field_data['optimal_temp_max']:
            temperature_stress = (weather_data['temperature'] - field_data['optimal_temp_max']) / 10
        elif weather_data['temperature'] < field_data['optimal_temp_min']:
            temperature_stress = (field_data['optimal_temp_min'] - weather_data['temperature']) / 10
        
        # Stress humidité
        if weather_data['humidity'] < field_data['humidity_optimal']:
            humidity_stress = (field_data['humidity_optimal'] - weather_data['humidity']) / 100
        
        # Stress précipitation
        if precipitation_forecast['avg_precipitation_probability'] < 30:
            precipitation_stress = 0.5
        
        # Score global (0 = aucun stress, 1 = stress maximal)
        total_stress = min((temperature_stress + humidity_stress + precipitation_stress) / 3, 1.0)
        
        return total_stress
    
    def generate_recommendation(self, field_id):
        """Génère une recommandation agricole pour un champ"""
        # Récupérer les données du champ
        field_data = self.get_field_with_crop(field_id)
        if not field_data:
            print(f"⚠️ Champ {field_id} non trouvé")
            return None
        
        # Récupérer la météo
        weather_data = self.get_latest_weather(field_data['location'])
        if not weather_data:
            print(f"⚠️ Pas de données météo pour {field_data['location']}")
            return None
        
        # Récupérer les prévisions de pluie
        precipitation_forecast = self.get_forecast_precipitation(field_data['location'])
        
        # Calculer le stress hydrique
        water_stress = self.calculate_water_stress(field_data, weather_data, precipitation_forecast)
        
        # Déterminer le niveau de risque
        if water_stress < 0.3:
            risk_level = 'low'
            risk_description = 'Conditions favorables'
        elif water_stress < 0.6:
            risk_level = 'medium'
            risk_description = 'Surveillance recommandée'
        else:
            risk_level = 'high'
            risk_description = 'Action requise'
        
        # Calculer les besoins en irrigation
        irrigation_needed = water_stress > 0.4 and precipitation_forecast['avg_precipitation_probability'] < 40
        
        if irrigation_needed:
            # Besoins en eau (mm) = besoins culture * facteur stress * surface
            irrigation_amount = field_data['water_need_daily'] * (1 + water_stress) * field_data['area_hectares'] * 10
        else:
            irrigation_amount = 0
        
        # Déterminer le type de risque
        if weather_data['temperature'] > field_data['optimal_temp_max'] + 5:
            risk_type = 'chaleur_extreme'
        elif water_stress > 0.6:
            risk_type = 'secheresse'
        elif precipitation_forecast['avg_precipitation_probability'] > 70:
            risk_type = 'pluies_excessives'
        elif weather_data['humidity'] > 85 and weather_data['temperature'] > 25:
            risk_type = 'risque_maladies'
        else:
            risk_type = 'normal'
        
        # Générer l'action recommandée
        actions = []
        if irrigation_needed:
            actions.append(f"Irrigation recommandée: {irrigation_amount:.1f}mm sur {field_data['area_hectares']}ha")
        
        if risk_type == 'chaleur_extreme':
            actions.append("Surveiller les plants, envisager ombrage")
        elif risk_type == 'risque_maladies':
            actions.append("Conditions favorables aux maladies fongiques, surveiller")
        elif risk_type == 'pluies_excessives':
            actions.append("Vérifier drainage, reporter traitements")
        
        if not actions:
            actions.append("Continuer surveillance normale")
        
        recommendation = {
            'field_id': field_id,
            'field_name': field_data['field_name'],
            'crop': field_data['crop_name'],
            'location': field_data['location'],
            'recommendation_date': datetime.now(),
            'temperature': weather_data['temperature'],
            'humidity': weather_data['humidity'],
            'precipitation_forecast': precipitation_forecast['avg_precipitation_probability'],
            'water_stress': water_stress,
            'irrigation_needed': irrigation_needed,
            'irrigation_amount_mm': irrigation_amount,
            'risk_level': risk_level,
            'risk_type': risk_type,
            'risk_description': risk_description,
            'actions': actions
        }
        
        return recommendation
    
    def save_recommendation(self, recommendation):
        """Sauvegarde une recommandation dans la base"""
        cursor = self.connection.cursor()
        
        query = """
            INSERT INTO agricultural_recommendations 
            (field_id, recommendation_date, temperature, humidity, precipitation_forecast,
             irrigation_needed, irrigation_amount_mm, risk_level, risk_type, action_recommended)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """
        
        cursor.execute(query, (
            recommendation['field_id'],
            recommendation['recommendation_date'],
            recommendation['temperature'],
            recommendation['humidity'],
            recommendation['precipitation_forecast'],
            recommendation['irrigation_needed'],
            recommendation['irrigation_amount_mm'],
            recommendation['risk_level'],
            recommendation['risk_type'],
            '\n'.join(recommendation['actions'])
        ))
        
        self.connection.commit()
        cursor.close()
        print(f"✓ Recommandation sauvegardée pour {recommendation['field_name']}")
    
    def generate_all_recommendations(self):
        """Génère des recommandations pour tous les champs"""
        cursor = self.connection.cursor()
        cursor.execute("SELECT id FROM fields")
        field_ids = [row[0] for row in cursor.fetchall()]
        cursor.close()
        
        print(f"\n🌾 Génération de recommandations pour {len(field_ids)} champs...\n")
        
        recommendations = []
        for field_id in field_ids:
            rec = self.generate_recommendation(field_id)
            if rec:
                self.save_recommendation(rec)
                recommendations.append(rec)
                self.print_recommendation(rec)
        
        return recommendations
    
    def print_recommendation(self, rec):
        """Affiche une recommandation"""
        print("=" * 70)
        print(f"📍 {rec['field_name']} ({rec['location']}) - Culture: {rec['crop']}")
        print(f"🌡️  Température: {rec['temperature']:.1f}°C | Humidité: {rec['humidity']:.0f}%")
        print(f"🌧️  Prévision pluie: {rec['precipitation_forecast']:.0f}%")
        print(f"💧 Stress hydrique: {rec['water_stress']:.2f}")
        
        if rec['risk_level'] == 'low':
            emoji = "✅"
        elif rec['risk_level'] == 'medium':
            emoji = "⚠️"
        else:
            emoji = "🚨"
        
        print(f"{emoji} Niveau de risque: {rec['risk_level'].upper()} - {rec['risk_description']}")
        print(f"🔧 Actions recommandées:")
        for action in rec['actions']:
            print(f"   → {action}")
        print("=" * 70 + "\n")
    
    def close(self):
        """Ferme la connexion"""
        if self.connection:
            self.connection.close()

if __name__ == "__main__":
    ai = AgriculturalIntelligence()
    ai.generate_all_recommendations()
    ai.close()