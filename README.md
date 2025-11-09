# 🌿 Weather-Agri – Plateforme de Gestion Agricole Intelligente

![Python](https://img.shields.io/badge/Python-3.10+-blue.svg)
![FastAPI](https://img.shields.io/badge/FastAPI-Backend-green.svg)
![Flutter](https://img.shields.io/badge/Flutter-Mobile-blue.svg)
![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)

> **Weather-Agri** est une application  mobile multi-plate-forme qui aide les agriculteurs à gérer leurs champs, suivre leurs cultures et obtenir des prévisions météorologiques locales basées sur leur position.  
> Développée dans le cadre da la  **deuxième édition du Hack2Hire de Data-Beez @2025**, elle combine **FastAPI(models de prédictions)**, **Flutter**, **PostgreSQL**, **Prometheus**, **Grafana**, et **Docker**.

---

## 🧩 Architecture du Projet

  ### 🏗️ Structure Backend/Frontend

  weather-agri-platform/  
  
      Api/  
          routers/ # différentes Routes de  l'api  
          main.py # Entrée principale de l’API  
          models.py # Modèles SQLAlchemy  
          schemas.py # Schémas Pydantic  
          database.py # Connexion à PostgreSQL  
          requirements.txt # Dépendances Python  
          Dockerfile # Image du backend  
          prometheus.yml # Config Prometheus pour les métriques  

      app-flutter/  
          lib/  
              pages/ # pages de details des predictions des differents models  
              presentation/ # Écrans (auth, champs, profil)  
              services/ # Services API & translation 
              main.dart # Entrée Flutter
              constants.dart # Constantes et configuration  
          pubspec.yaml  

      data/ # données d'entraînement des modèles  
      db/  #base de données  
      docs/ # demo de la solution  
      etl/ # scripts etl  
      lms/ # resultats quiz  
      presentation/ #documents de présentation  
      team/ # membres de l'équipe 
      README.md # Documentation
      


---

## ⚙️ Technologies utilisées

| Composant | Technologie |
|------------|-------------|
| **Backend API** | [FastAPI](https://fastapi.tiangolo.com/) (Python 3.10) |
| **Base de données** | PostgreSQL |
| **Frontend Mobile** | [Flutter](https://flutter.dev/) |
| **Monitoring** | Prometheus + Grafana |
| **MLOps / Conteneurisation** | Docker & Docker Compose |

---

## 🚀 Installation et Lancement

### 🧰 1. Prérequis

Avant de démarrer, assurez-vous d’avoir installé :

- [Python 3.10+](https://www.python.org/downloads/)
- [Docker & Docker Compose](https://docs.docker.com/get-docker/)
- [Flutter SDK](https://flutter.dev/docs/get-started/install)
- [Git](https://git-scm.com/)

---

### 🐍 2. Installation Backend (FastAPI)

```bash
# Cloner le projet
git clone https://github.com/Drakariss02/weather-agri-platform.git
cd weather-agri-platform/api

# Créer un environnement virtuel
python -m venv venv
source venv/bin/activate  # (ou venv\Scripts\activate sous Windows)

# Installer les dépendances
pip install -r requirements.txt

# Lancer le serveur
uvicorn main:app --reload

L’API sera disponible sur :
👉 http://127.0.0.1:8000

Accédez à la documentation interactive Swagger :
👉 http://127.0.0.1:8000/docs



📱 3. Lancer le Frontend Flutter

cd app-flutter
flutter pub get
flutter run

🐳 4. Lancement backend via Docker Compose     
               
# au niveau de api/
docker-compose up --build

Services disponibles :

| Service         | URL                                                            |
| --------------- | -------------------------------------------------------------- |
| **API FastAPI** | [http://localhost:8000](http://localhost:8000)                 |
| **Prometheus**  | [http://localhost:9090](http://localhost:9090)                 |
| **Grafana**     | [http://localhost:3000](http://localhost:3000) (admin / admin) |
| **PostgreSQL**  | localhost:5432                                                 |


🧠 Fonctionnalités principales

✅Tableau de bord
✅ Graphiques //  évolution pluie, sècheresse,risque de maladie, irrigation recommandée
✅ option langue (français/wolof/peul)
✅ Gestion des champs (CRUD)
✅ Autocomplétion des localités via GeoNames API
✅ Récupération automatique latitude / longitude
✅ Authentification utilisateur (agriculteurs)
✅ Intégration prédictions des models (API externe)
✅ Monitoring des performances via Prometheus
✅ Visualisation Grafana en temps réel
✅ Conteneurisation complète avec Docker
...........................................


🧑‍💻 Contributeurs
Mamadou Cissokho ( Data scientiste/ chef de projet)
Mamie Naar Séne ( Data engineer)
Ibrahima Faye ( Data scientiste)
Rama seck (software engineer)
          
          
    
