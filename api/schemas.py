from pydantic import BaseModel
from typing import Optional
from datetime import date

class AgriculteurBase(BaseModel):
    nom_complet: str
    telephone: str
    langue: str

class AgriculteurCreate(AgriculteurBase):
    mot_de_passe: str

class AgriculteurOut(AgriculteurBase):
    id: int
    class Config:
        orm_mode = True

class ChampsBase(BaseModel):
    culture: str
    superficie: float
    date_semi: date
    localite: str
    latitude: float
    longitude: float

class ChampsCreate(ChampsBase):
    id_agriculteur: int

class ChampsOut(ChampsBase):
    id: int
    class Config:
        orm_mode = True



class ChampsUpdate(BaseModel):
    culture: Optional[str]
    superficie: Optional[float]
    date_semi: Optional[date]
    localite: Optional[str]
    latitude: Optional[float]
    longitude: Optional[float]


