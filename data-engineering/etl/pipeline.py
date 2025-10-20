#!/usr/bin/env python3
"""
Pipeline ETL Weather Agricultural Data
Extract → Transform → Load → Intelligence Agricole
"""

from datetime import datetime
from extract import WeatherExtractor
from transform import DataTransformer
from load import DataLoader
from agricultural_intelligence import AgriculturalIntelligence
import sys

def run_pipeline():
    """Exécute le pipeline ETL complet"""
    
    print("\n" + "=" * 70)
    print("🚀 DÉMARRAGE DU PIPELINE ETL WEATHER-AGRI")
    print("=" * 70)
    print(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
    
    try:
        # ==================== EXTRACT ====================
        print("📥 ÉTAPE 1/4: EXTRACTION")
        print("-" * 70)
        
        extractor = WeatherExtractor()
        observations, forecasts = extractor.extract_all()
        
        if not observations and not forecasts:
            print("\n⚠️  Aucune donnée extraite. Vérifiez votre clé API et votre connexion.")
            return False
        
        # ==================== TRANSFORM ====================
        print("\n" + "=" * 70)
        print("🔄 ÉTAPE 2/4: TRANSFORMATION")
        print("-" * 70)
        
        transformer = DataTransformer()
        
        transformed_observations = transformer.transform_observations(observations)
        transformed_forecasts = transformer.transform_forecasts(forecasts)
        
        # Afficher le rapport de qualité
        transformer.print_quality_report()
        
        # ==================== LOAD ====================
        print("\n" + "=" * 70)
        print("💾 ÉTAPE 3/4: CHARGEMENT")
        print("-" * 70)
        
        loader = DataLoader()
        
        # Charger les observations
        obs_loaded = loader.load_observations(transformed_observations)
        
        # Charger les prévisions
        forecasts_loaded = loader.load_forecasts(transformed_forecasts)
        
        # Charger le rapport de qualité
        loader.load_quality_report(transformer.get_quality_report())
        
        # Afficher les statistiques finales
        loader.print_statistics()
        
        # Fermer la connexion
        loader.close()
        
        # ==================== INTELLIGENCE AGRICOLE ====================
        print("\n" + "=" * 70)
        print("🌾 ÉTAPE 4/4: RECOMMANDATIONS AGRICOLES")
        print("-" * 70)
        
        agri_ai = AgriculturalIntelligence()
        recommendations = agri_ai.generate_all_recommendations()
        agri_ai.close()
        
        # ==================== RÉSUMÉ ====================
        print("\n" + "=" * 70)
        print("✅ PIPELINE ETL TERMINÉ AVEC SUCCÈS")
        print("=" * 70)
        print(f"📊 Résumé:")
        print(f"   - Observations extraites: {len(observations)}")
        print(f"   - Observations chargées: {obs_loaded}")
        print(f"   - Prévisions extraites: {len(forecasts)}")
        print(f"   - Prévisions chargées: {forecasts_loaded}")
        print(f"   - Recommandations agricoles: {len(recommendations)}")
        print(f"   - Qualité des données: {transformer.get_quality_report()['observations']['completeness_rate']:.1f}%")
        print(f"   - Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print("=" * 70 + "\n")
        
        return True
        
    except Exception as e:
        print("\n" + "=" * 70)
        print("❌ ERREUR DANS LE PIPELINE")
        print("=" * 70)
        print(f"Erreur: {str(e)}")
        print("=" * 70 + "\n")
        return False

if __name__ == "__main__":
    success = run_pipeline()
    
    # Code de sortie pour l'automatisation
    sys.exit(0 if success else 1)