# models.py
#
# SQLAlchemy models — the Python equivalent of the CREATE TABLE
# statements you already ran in Postgres. This doesn't create new
# tables; it describes the ones that already exist so Python code
# can read/write them without writing raw SQL.
#
# requirements.txt needs:
#   sqlalchemy
#   psycopg2-binary   (the actual PostgreSQL driver)

import uuid
from sqlalchemy import Column, String, Integer, Text, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from database import Base  # Base comes from database.py — every model inherits from it


class Patient(Base):
    __tablename__ = "patients"

    user_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(100), nullable=False)
    age = Column(Integer)
    language_preference = Column(String(50), default="Assamese")
    baseline_score = Column(Integer, default=50)
    created_at = Column(DateTime, server_default=func.now())
    synced = Column(Integer, default=1)  # rows created server-side start "synced"

    # This is what ON DELETE CASCADE looks like from the Python side —
    # deleting a Patient object also deletes its related sessions.
    game_sessions = relationship(
        "GameSession", back_populates="patient", cascade="all, delete-orphan"
    )
    music_sessions = relationship(
        "MusicSession", back_populates="patient", cascade="all, delete-orphan"
    )
    alerts = relationship(
        "CaregiverAlert", back_populates="patient", cascade="all, delete-orphan"
    )


class GameSession(Base):
    __tablename__ = "game_sessions"

    session_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("patients.user_id", ondelete="CASCADE"))
    game_type = Column(String(50), nullable=False)
    completion_time_sec = Column(Integer, nullable=False)
    errors_made = Column(Integer, nullable=False)
    engagement_score = Column(Integer, nullable=False)
    timestamp = Column(DateTime, server_default=func.now())

    patient = relationship("Patient", back_populates="game_sessions")


class MusicSession(Base):
    __tablename__ = "music_sessions"

    session_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("patients.user_id", ondelete="CASCADE"))
    track_id = Column(String(50), nullable=False)
    engagement_indicator = Column(String(50))
    timestamp = Column(DateTime, server_default=func.now())

    patient = relationship("Patient", back_populates="music_sessions")


class CaregiverAlert(Base):
    __tablename__ = "caregiver_alerts"

    alert_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("patients.user_id", ondelete="CASCADE"))
    alert_type = Column(String(50), nullable=False)
    message = Column(Text, nullable=False)
    created_at = Column(DateTime, server_default=func.now())

    patient = relationship("Patient", back_populates="alerts")