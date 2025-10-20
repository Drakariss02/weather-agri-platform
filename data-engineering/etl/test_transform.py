from extract import WeatherExtractor
from transform import DataTransformer
from load import DataLoader

# 1. EXTRACTION
print("=" * 60)
print("ÉTAPE 1: EXTRACTION")
print("=" * 60)
extractor = WeatherExtractor()
observations, forecasts = extractor.extract_all()

# 2. TRANSFORMATION
print("\n" + "=" * 60)
print("ÉTAPE 2: TRANSFORMATION")
print("=" * 60)
transformer = DataTransformer()
transformed_obs = transformer.transform_observations(observations)
transformed_forecasts = transformer.transform_forecasts(forecasts)
transformer.print_quality_report()

# 3. CHARGEMENT
print("\n" + "=" * 60)
print("ÉTAPE 3: CHARGEMENT")
print("=" * 60)
loader = DataLoader()
loader.load_observations(transformed_obs)
loader.load_forecasts(transformed_forecasts)
loader.load_quality_report(transformer.get_quality_report())

# 4. STATISTIQUES
loader.print_statistics()
loader.close()

print("\n🎉 Pipeline ETL terminé avec succès!")