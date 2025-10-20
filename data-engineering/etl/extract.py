import os
import requests
from datetime import datetime
from dotenv import load_dotenv

load_dotenv()

class WeatherExtractor:
    def __init__(self):
        self.api_key = os.getenv('OPENWEATHER_API_KEY')
        self.base_url = "http://api.openweathermap.org/data/2.5"
        self.locations = os.getenv('LOCATIONS', 'Dakar').split(',')
        
    def extract_current_weather(self, location):
        """Extrait les données météo actuelles pour une localité"""
        try:
            url = f"{self.base_url}/weather"
            params = {
                'q': f"{location},SN",  # SN pour Sénégal
                'appid': self.api_key,
                'units': 'metric',
                'lang': 'fr'
            }
            
            response = requests.get(url, params=params)
            response.raise_for_status()
            data = response.json()
            
            observation = {
                'location': location,
                'timestamp': datetime.fromtimestamp(data['dt']),
                'temperature': data['main']['temp'],
                'humidity': data['main']['humidity'],
                'pressure': data['main']['pressure'],
                'wind_speed': data['wind']['speed'],
                'wind_direction': data['wind'].get('deg', 0),
                'weather_description': data['weather'][0]['description']
            }
            
            print(f"✓ Données actuelles extraites pour {location}")
            return observation
            
        except requests.exceptions.RequestException as e:
            print(f"✗ Erreur extraction {location}: {e}")
            return None
    
    def extract_forecast(self, location):
        """Extrait les prévisions météo pour une localité"""
        try:
            url = f"{self.base_url}/forecast"
            params = {
                'q': f"{location},SN",
                'appid': self.api_key,
                'units': 'metric',
                'lang': 'fr'
            }
            
            response = requests.get(url, params=params)
            response.raise_for_status()
            data = response.json()
            
            forecasts = []
            for item in data['list'][:8]:  # 8 prochaines périodes (24h)
                forecast = {
                    'location': location,
                    'forecast_timestamp': datetime.fromtimestamp(item['dt']),
                    'temperature': item['main']['temp'],
                    'temperature_min': item['main']['temp_min'],
                    'temperature_max': item['main']['temp_max'],
                    'humidity': item['main']['humidity'],
                    'pressure': item['main']['pressure'],
                    'wind_speed': item['wind']['speed'],
                    'weather_description': item['weather'][0]['description'],
                    'precipitation_probability': item.get('pop', 0) * 100
                }
                forecasts.append(forecast)
            
            print(f"✓ {len(forecasts)} prévisions extraites pour {location}")
            return forecasts
            
        except requests.exceptions.RequestException as e:
            print(f"✗ Erreur extraction prévisions {location}: {e}")
            return []
    
    def extract_all(self):
        """Extrait toutes les données pour toutes les localités"""
        observations = []
        all_forecasts = []
        
        print(f"\n🌤️  Extraction des données météo pour {len(self.locations)} localités...")
        print(f"Localités: {', '.join(self.locations)}\n")
        
        for location in self.locations:
            location = location.strip()
            
            # Observations actuelles
            obs = self.extract_current_weather(location)
            if obs:
                observations.append(obs)
            
            # Prévisions
            forecasts = self.extract_forecast(location)
            all_forecasts.extend(forecasts)
        
        print(f"\n📊 Résumé extraction:")
        print(f"   - Observations: {len(observations)}")
        print(f"   - Prévisions: {len(all_forecasts)}")
        
        return observations, all_forecasts

if __name__ == "__main__":
    extractor = WeatherExtractor()
    observations, forecasts = extractor.extract_all()