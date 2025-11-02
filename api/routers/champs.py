from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from database import get_db
from models import Champs, Agriculteur
from schemas import ChampsCreate, ChampsOut, ChampsUpdate

router = APIRouter()

@router.post("/", response_model=ChampsOut, status_code=201)
def create_champ(data: ChampsCreate, db: Session = Depends(get_db)):
    agriculteur = db.query(Agriculteur).filter(Agriculteur.id == data.id_agriculteur).first()
    if not agriculteur:
        raise HTTPException(status_code=404, detail="Agriculteur introuvable")

    champ = Champs(**data.dict())
    db.add(champ)
    db.commit()
    db.refresh(champ)
    return champ


@router.get("/agriculteur/{id_agriculteur}", response_model=List[ChampsOut])
def get_champs_by_agriculteur(id_agriculteur: int, db: Session = Depends(get_db)):
    champs = (
        db.query(Champs)
        .filter(Champs.id_agriculteur == id_agriculteur)
        .order_by(Champs.id.asc())
        .all()
    )
    if not champs:
        raise HTTPException(status_code=404, detail="Aucun champ trouvé pour cet agriculteur")
    return champs


@router.get("/principal/{id_agriculteur}", response_model=ChampsOut)
def get_champ_principal(id_agriculteur: int, db: Session = Depends(get_db)):
    champ = (
        db.query(Champs)
        .filter(Champs.id_agriculteur == id_agriculteur)
        .order_by(Champs.id.asc())
        .first()
    )
    if not champ:
        raise HTTPException(status_code=404, detail="Aucun champ trouvé pour cet agriculteur")
    return champ


@router.put("/{id}", response_model=ChampsOut)
def update_champ(id: int, data: ChampsUpdate, db: Session = Depends(get_db)):
    champ = db.query(Champs).filter(Champs.id == id).first()
    if not champ:
        raise HTTPException(status_code=404, detail="Champ introuvable")

    for key, value in data.dict(exclude_unset=True).items():
        setattr(champ, key, value)

    db.commit()
    db.refresh(champ)
    return champ


@router.delete("/{id}", status_code=204)
def delete_champ(id: int, db: Session = Depends(get_db)):
    champ = db.query(Champs).filter(Champs.id == id).first()
    if not champ:
        raise HTTPException(status_code=404, detail="Champ introuvable")

    db.delete(champ)
    db.commit()
    return {"message": "Champ supprimé avec succès"}
