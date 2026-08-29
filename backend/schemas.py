from pydantic import BaseModel
from typing import Optional, Dict, Any
from uuid import UUID
from datetime import datetime

class PatientCreate(BaseModel):
    user_id: UUID
    registration_number: Optional[str] = None
    name: str
    email: Optional[str] = None
    phone: Optional[str] = None
    password: Optional[str] = None
    age: Optional[int] = None
    photo: Optional[str] = None
    language_preference: Optional[str] = "Assamese"
    baseline_score: Optional[int] = 50
    cumulative_score: Optional[int] = 0
    daily_score: Optional[int] = 0
    current_streak: Optional[int] = 0
    last_activity_date: Optional[str] = None

class PatientOut(PatientCreate):
    created_at: datetime

    class Config:
        from_attributes = True

class CaregiverCreate(BaseModel):
    caregiver_id: UUID
    name: str
    email: Optional[str] = None
    phone: Optional[str] = None
    password: Optional[str] = None
    institution: Optional[str] = None

class CaregiverOut(CaregiverCreate):
    created_at: datetime

    class Config:
        from_attributes = True

class CaregiverPatientLink(BaseModel):
    caregiver_id: UUID
    patient_id: UUID

class LoginRequest(BaseModel):
    identifier: str
    password: str

class LoginResponse(BaseModel):
    role: str
    data: Dict[str, Any]

class GameSessionCreate(BaseModel):
    session_id: UUID
    user_id: UUID
    game_type: str
    completion_time_sec: int
    errors_made: int
    engagement_score: int

class GameSessionOut(GameSessionCreate):
    timestamp: datetime

    class Config:
        from_attributes = True

class MusicSessionCreate(BaseModel):
    session_id: UUID
    user_id: UUID
    track_id: str
    engagement_indicator: Optional[str] = None

class MusicSessionOut(MusicSessionCreate):
    timestamp: datetime

    class Config:
        from_attributes = True


class RegionalMusicPlayCreate(BaseModel):
    play_id: UUID
    user_id: UUID
    state_name: str
    song_title: str
    duration_seconds: int = 0
    loop_count: int = 0
    emotional_state: Optional[str] = None
    cognitive_response: Optional[str] = None


class RegionalMusicPlayOut(RegionalMusicPlayCreate):
    timestamp: datetime
    synced: int = 1

    class Config:
        from_attributes = True

class ChatRequest(BaseModel):
    message: str

class ChatResponse(BaseModel):
    reply: str