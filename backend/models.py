import uuid
from sqlalchemy import Column, String, Integer, Text, DateTime, ForeignKey, Table
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from database import Base

# Cross-compatible string type for UUID across SQLite and PostgreSQL
UUID_TYPE = String(36)

caregiver_patients = Table(
    "caregiver_patients",
    Base.metadata,
    Column("caregiver_id", UUID_TYPE, ForeignKey("caregivers.caregiver_id", ondelete="CASCADE"), primary_key=True),
    Column("patient_id", UUID_TYPE, ForeignKey("patients.user_id", ondelete="CASCADE"), primary_key=True)
)

class Caregiver(Base):
    __tablename__ = "caregivers"

    caregiver_id = Column(UUID_TYPE, primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String(100), nullable=False)
    email = Column(String(255), unique=True, nullable=True)
    phone = Column(String(20), unique=True, nullable=True)
    password = Column(String(255), nullable=True)
    institution = Column(String(255), nullable=True)
    created_at = Column(DateTime, server_default=func.now())
    synced = Column(Integer, default=1)

    patients = relationship("Patient", secondary=caregiver_patients, back_populates="caregivers")

class Patient(Base):
    __tablename__ = "patients"

    user_id = Column(UUID_TYPE, primary_key=True, default=lambda: str(uuid.uuid4()))
    registration_number = Column(String(50), unique=True, nullable=True)
    name = Column(String(100), nullable=False)
    email = Column(String(255), unique=True, nullable=True)
    phone = Column(String(20), unique=True, nullable=True)
    password = Column(String(255), nullable=True)
    age = Column(Integer)
    photo = Column(Text, nullable=True)
    language_preference = Column(String(50), default="Assamese")
    baseline_score = Column(Integer, default=50)
    cumulative_score = Column(Integer, default=0)
    daily_score = Column(Integer, default=0)
    current_streak = Column(Integer, default=0)
    last_activity_date = Column(String(20), nullable=True)
    created_at = Column(DateTime, server_default=func.now())
    synced = Column(Integer, default=1)

    caregivers = relationship("Caregiver", secondary=caregiver_patients, back_populates="patients")
    game_sessions = relationship("GameSession", back_populates="patient", cascade="all, delete-orphan")
    music_sessions = relationship("MusicSession", back_populates="patient", cascade="all, delete-orphan")

class GameSession(Base):
    __tablename__ = "game_sessions"

    session_id = Column(UUID_TYPE, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(UUID_TYPE, ForeignKey("patients.user_id", ondelete="CASCADE"))
    game_type = Column(String(50), nullable=False)
    completion_time_sec = Column(Integer, nullable=False)
    errors_made = Column(Integer, nullable=False)
    engagement_score = Column(Integer, nullable=False)
    timestamp = Column(DateTime, server_default=func.now())

    patient = relationship("Patient", back_populates="game_sessions")

class MusicSession(Base):
    __tablename__ = "music_sessions"

    session_id = Column(UUID_TYPE, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(UUID_TYPE, ForeignKey("patients.user_id", ondelete="CASCADE"))
    track_id = Column(String(50), nullable=False)
    engagement_indicator = Column(String(50))
    timestamp = Column(DateTime, server_default=func.now())

    patient = relationship("Patient", back_populates="music_sessions")