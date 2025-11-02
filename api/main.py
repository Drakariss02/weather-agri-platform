from fastapi import FastAPI
from routers import auth , rain, secheresse, irrigation, maladie, champs
from database import Base, engine

app = FastAPI(
    title="🌦️ Weather-Agri Prediction API",
    description="API de prédiction et gestion des agriculteurs/champs",
    version="1.1.0"
)

# Création auto des tables
Base.metadata.create_all(bind=engine)

# Routes IA
app.include_router(rain.router, prefix="/predict/rain", tags=["Rain"])
app.include_router(secheresse.router, prefix="/predict/secheresse", tags=["Sécheresse"])
app.include_router(irrigation.router, prefix="/predict/irrigation", tags=["Irrigation"])
app.include_router(maladie.router, prefix="/predict/maladie", tags=["Maladie"])

# Routes Auth / Données
app.include_router(auth.router, prefix="/auth", tags=["Authentification"])
app.include_router(champs.router, prefix="/champs", tags=["Champs"])

@app.get("/")
def home():
    return {"message": "Bienvenue sur l'API Weather-Agri 🌿"}
