from datetime import datetime

class DataTransformer:
    def __init__(self):
        # Ranges de validation pour le Sénégal (climat tropical)
        self.validation_rules = {
            'temperature': {'min': -5, 'max': 55},  # °C
            'humidity': {'min': 0, 'max': 100},  # %
            'pressure': {'min': 950, 'max': 1050},  # hPa
            'wind_speed': {'min': 0, 'max': 150},  # m/s
            'wind_direction': {'min': 0, 'max': 360},  # degrés
            'precipitation_probability': {'min': 0, 'max': 100}  # %
        }
        
        self.quality_report = {
            'timestamp': datetime.now(),
            'observations': {'total': 0, 'valid': 0, 'invalid': 0, 'issues': []},
            'forecasts': {'total': 0, 'valid': 0, 'invalid': 0, 'issues': []}
        }
    
    def validate_value(self, field, value, record_id):
        """Valide une valeur selon les règles définies"""
        if value is None:
            return False, f"Valeur manquante pour {field}"
        
        if field in self.validation_rules:
            rules = self.validation_rules[field]
            if value < rules['min'] or value > rules['max']:
                return False, f"{field}={value} hors range [{rules['min']}, {rules['max']}]"
        
        return True, None
    
    def transform_observation(self, obs, index):
        """Transforme et valide une observation"""
        is_valid = True
        issues = []
        
        # Vérifier les champs requis
        required_fields = ['location', 'timestamp', 'temperature', 'humidity', 'pressure']
        for field in required_fields:
            if field not in obs or obs[field] is None:
                is_valid = False
                issues.append(f"Champ requis manquant: {field}")
        
        # Valider les valeurs numériques
        numeric_fields = ['temperature', 'humidity', 'pressure', 'wind_speed', 'wind_direction']
        for field in numeric_fields:
            if field in obs and obs[field] is not None:
                valid, error = self.validate_value(field, obs[field], index)
                if not valid:
                    is_valid = False
                    issues.append(error)
        
        # Nettoyer les données
        transformed = obs.copy()
        if 'location' in transformed:
            transformed['location'] = transformed['location'].strip().title()
        
        return transformed, is_valid, issues
    
    def transform_forecast(self, forecast, index):
        """Transforme et valide une prévision"""
        is_valid = True
        issues = []
        
        # Vérifier les champs requis
        required_fields = ['location', 'forecast_timestamp', 'temperature', 'humidity']
        for field in required_fields:
            if field not in forecast or forecast[field] is None:
                is_valid = False
                issues.append(f"Champ requis manquant: {field}")
        
        # Valider les valeurs numériques
        numeric_fields = ['temperature', 'temperature_min', 'temperature_max', 
                         'humidity', 'pressure', 'wind_speed', 'precipitation_probability']
        for field in numeric_fields:
            if field in forecast and forecast[field] is not None:
                valid, error = self.validate_value(field, forecast[field], index)
                if not valid:
                    is_valid = False
                    issues.append(error)
        
        # Vérifier la cohérence min/max
        if all(k in forecast for k in ['temperature_min', 'temperature_max']):
            if forecast['temperature_min'] > forecast['temperature_max']:
                is_valid = False
                issues.append("temperature_min > temperature_max")
        
        # Nettoyer les données
        transformed = forecast.copy()
        if 'location' in transformed:
            transformed['location'] = transformed['location'].strip().title()
        
        return transformed, is_valid, issues
    
    def transform_observations(self, observations):
        """Transforme toutes les observations"""
        transformed = []
        
        print(f"\n🔄 Transformation de {len(observations)} observations...")
        
        for i, obs in enumerate(observations):
            trans_obs, is_valid, issues = self.transform_observation(obs, i)
            transformed.append(trans_obs)
            
            self.quality_report['observations']['total'] += 1
            if is_valid:
                self.quality_report['observations']['valid'] += 1
            else:
                self.quality_report['observations']['invalid'] += 1
                self.quality_report['observations']['issues'].extend(
                    [f"Obs {i} ({obs.get('location', 'unknown')}): {issue}" for issue in issues]
                )
        
        print(f"✓ Observations transformées: {len(transformed)}")
        return transformed
    
    def transform_forecasts(self, forecasts):
        """Transforme toutes les prévisions"""
        transformed = []
        
        print(f"🔄 Transformation de {len(forecasts)} prévisions...")
        
        for i, forecast in enumerate(forecasts):
            trans_forecast, is_valid, issues = self.transform_forecast(forecast, i)
            transformed.append(trans_forecast)
            
            self.quality_report['forecasts']['total'] += 1
            if is_valid:
                self.quality_report['forecasts']['valid'] += 1
            else:
                self.quality_report['forecasts']['invalid'] += 1
                self.quality_report['forecasts']['issues'].extend(
                    [f"Prev {i} ({forecast.get('location', 'unknown')}): {issue}" for issue in issues]
                )
        
        print(f"✓ Prévisions transformées: {len(transformed)}\n")
        return transformed
    
    def get_quality_report(self):
        """Retourne le rapport de qualité"""
        report = self.quality_report.copy()
        
        # Calculer les taux de complétude
        if report['observations']['total'] > 0:
            report['observations']['completeness_rate'] = (
                report['observations']['valid'] / report['observations']['total'] * 100
            )
        else:
            report['observations']['completeness_rate'] = 0
        
        if report['forecasts']['total'] > 0:
            report['forecasts']['completeness_rate'] = (
                report['forecasts']['valid'] / report['forecasts']['total'] * 100
            )
        else:
            report['forecasts']['completeness_rate'] = 0
        
        return report
    
    def print_quality_report(self):
        """Affiche le rapport de qualité"""
        report = self.get_quality_report()
        
        print("=" * 60)
        print("📊 RAPPORT DE QUALITÉ DES DONNÉES")
        print("=" * 60)
        print(f"\n🔹 OBSERVATIONS:")
        print(f"   Total: {report['observations']['total']}")
        print(f"   Valides: {report['observations']['valid']}")
        print(f"   Invalides: {report['observations']['invalid']}")
        print(f"   Taux de complétude: {report['observations']['completeness_rate']:.1f}%")
        
        if report['observations']['issues']:
            print(f"\n   ⚠️  Problèmes détectés:")
            for issue in report['observations']['issues'][:5]:
                print(f"      - {issue}")
            if len(report['observations']['issues']) > 5:
                print(f"      ... et {len(report['observations']['issues']) - 5} autres")
        
        print(f"\n🔹 PRÉVISIONS:")
        print(f"   Total: {report['forecasts']['total']}")
        print(f"   Valides: {report['forecasts']['valid']}")
        print(f"   Invalides: {report['forecasts']['invalid']}")
        print(f"   Taux de complétude: {report['forecasts']['completeness_rate']:.1f}%")
        
        if report['forecasts']['issues']:
            print(f"\n   ⚠️  Problèmes détectés:")
            for issue in report['forecasts']['issues'][:5]:
                print(f"      - {issue}")
            if len(report['forecasts']['issues']) > 5:
                print(f"      ... et {len(report['forecasts']['issues']) - 5} autres")
        
        print("\n" + "=" * 60)