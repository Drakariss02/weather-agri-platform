from fastapi import FastAPI
from routers import rain, secheresse, irrigation, maladie

app = FastAPI(
    title="🌦️ Weather-Agri Prediction API",
    description="API de prédiction météo-agricole (pluie, sécheresse, maladies, irrigation)",
    version="1.0.0"
)

app.include_router(rain.router, prefix="/predict/rain", tags=["Rain Prediction"])
app.include_router(secheresse.router, prefix="/predict/secheresse", tags=["secheresse Prediction"])
app.include_router(maladie.router, prefix="/predict/maladie", tags=["maladie Prediction"])
app.include_router(irrigation.router, prefix="/predict/irrigation", tags=["Irrigation Recommendation"])

@app.get("/")
def home():
    return {"message": "Bienvenue sur l'API Weather-Agri 🌿"}
