from sqlalchemy import Column, Integer, String, Float, Date, ForeignKey
from sqlalchemy.orm import relationship
from database import Base

class Agriculteur(Base):
    __tablename__ = "agriculteur"

    id = Column(Integer, primary_key=True, index=True)
    nom_complet = Column(String, nullable=False)
    telephone = Column(String, unique=True, nullable=False)
    mot_de_passe = Column(String, nullable=False)
    langue = Column(String, nullable=False)

    champs = relationship("Champs", back_populates="agriculteur")


class Champs(Base):
    __tablename__ = "champs"

    id = Column(Integer, primary_key=True, index=True)
    culture = Column(String, nullable=False)
    superficie = Column(Float, nullable=False)
    date_semi = Column(String, nullable=False)
    localite = Column(String, nullable=False)
    latitude = Column(Float)
    longitude = Column(Float)

    id_agriculteur = Column(Integer, ForeignKey("agriculteur.id"), nullable=False)
    agriculteur = relationship("Agriculteur", back_populates="champs")
