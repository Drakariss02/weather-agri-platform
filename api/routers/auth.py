from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from passlib.context import CryptContext
from database import get_db
from models import Agriculteur
from schemas import AgriculteurCreate, AgriculteurOut

router = APIRouter()

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

@router.post("/register", response_model=AgriculteurOut)
def register_user(data: AgriculteurCreate, db: Session = Depends(get_db)):
    if db.query(Agriculteur).filter(Agriculteur.telephone == data.telephone).first():
        raise HTTPException(status_code=400, detail="Téléphone déjà enregistré")

    hashed_pw = pwd_context.hash(data.mot_de_passe)
    agriculteur = Agriculteur(
        nom_complet=data.nom_complet,
        telephone=data.telephone,
        mot_de_passe=hashed_pw,
        langue=data.langue
    )
    db.add(agriculteur)
    db.commit()
    db.refresh(agriculteur)
    return agriculteur

@router.post("/login")
def login(telephone: str, mot_de_passe: str, db: Session = Depends(get_db)):
    user = db.query(Agriculteur).filter(Agriculteur.telephone == telephone).first()
    if not user or not pwd_context.verify(mot_de_passe, user.mot_de_passe):
        raise HTTPException(status_code=401, detail="Identifiants invalides")
    return {"id": user.id, "nom_complet": user.nom_complet, "langue": user.langue, "telephone":user.telephone}
