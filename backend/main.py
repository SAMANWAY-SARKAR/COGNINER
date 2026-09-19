import os
from pathlib import Path
from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from sqlalchemy import or_
from google import genai
from dotenv import load_dotenv

current_directory = Path(__file__).resolve().parent
env_path = current_directory / '.env'
load_dotenv(dotenv_path=env_path)

import models
import schemas
from database import Base, engine, SessionLocal

from pydantic import BaseModel
import json
import re
from google.genai import types

Base.metadata.create_all(bind=engine)

app = FastAPI(title="Cogniner Sync API")

# --- CORS CONFIGURATION ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def get_language_fallback(text: str) -> str:
    
    if re.search(r'[\u0980-\u09FF]', text):  # Bengali Script
        return "আমার কানেক্ট করতে সমস্যা হচ্ছে, তবে আমি আপনার সাথেই আছি।"
    elif re.search(r'[\u0900-\u097F]', text):  # Hindi Script
        return "मुझे अभी कनेक्ट करने में थोड़ी परेशानी हो रही है, लेकिन मैं आपके साथ हूँ।"
    return "I am having trouble connecting right now, but I am right here with you."

@app.get("/")
def root():
    return {"status": "Cogniner backend running"}

# --- AUTHENTICATION ---
@app.post("/login/", response_model=schemas.LoginResponse)
def login_user(credentials: schemas.LoginRequest, db: Session = Depends(get_db)):
    patient = db.query(models.Patient).filter(
        or_(models.Patient.email == credentials.identifier, models.Patient.phone == credentials.identifier),
        models.Patient.password == credentials.password
    ).first()
    
    if patient:
        return schemas.LoginResponse(role="patient", data=schemas.PatientOut.from_orm(patient).dict())

    caregiver = db.query(models.Caregiver).filter(
        or_(models.Caregiver.email == credentials.identifier, models.Caregiver.phone == credentials.identifier),
        models.Caregiver.password == credentials.password
    ).first()

    if caregiver:
        return schemas.LoginResponse(role="caregiver", data=schemas.CaregiverOut.from_orm(caregiver).dict())

    raise HTTPException(status_code=401, detail="Invalid email/phone or password.")

# --- CAREGIVER ENDPOINTS ---
@app.post("/caregivers/", response_model=schemas.CaregiverOut)
def sync_caregiver(caregiver: schemas.CaregiverCreate, db: Session = Depends(get_db)):
    existing = db.query(models.Caregiver).filter(models.Caregiver.caregiver_id == str(caregiver.caregiver_id)).first()
    if existing:
        for field, value in caregiver.dict(exclude_unset=True).items():
            setattr(existing, field, str(value) if isinstance(value, type(caregiver.caregiver_id)) else value)
        db.commit()
        db.refresh(existing)
        return existing

    db_data = caregiver.dict()
    db_data['caregiver_id'] = str(db_data['caregiver_id'])
    db_caregiver = models.Caregiver(**db_data)
    db.add(db_caregiver)
    db.commit()
    db.refresh(db_caregiver)
    return db_caregiver

@app.post("/caregiver-patients/")
def link_caregiver_patient(link: schemas.CaregiverPatientLink, db: Session = Depends(get_db)):
    caregiver = db.query(models.Caregiver).filter(models.Caregiver.caregiver_id == str(link.caregiver_id)).first()
    patient = db.query(models.Patient).filter(models.Patient.user_id == str(link.patient_id)).first()

    if not caregiver or not patient:
        raise HTTPException(status_code=404, detail="Caregiver or Patient not found.")

    if patient not in caregiver.patients:
        caregiver.patients.append(patient)
        db.commit()

    return {"status": "success"}

@app.get("/caregivers/{caregiver_id}/patients")
def get_caregiver_patients(caregiver_id: str, db: Session = Depends(get_db)):
    caregiver = db.query(models.Caregiver).filter(models.Caregiver.caregiver_id == caregiver_id).first()
    if not caregiver:
        raise HTTPException(status_code=404, detail="Caregiver not found.")

    return [schemas.PatientOut.from_orm(p) for p in caregiver.patients]

# --- PATIENT ENDPOINTS ---
@app.get("/patients/search/{reg_number}", response_model=schemas.PatientOut)
def search_patient_by_reg_number(reg_number: str, db: Session = Depends(get_db)):
    patient = db.query(models.Patient).filter(models.Patient.registration_number == reg_number).first()
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found.")
    return patient

@app.post("/patients/", response_model=schemas.PatientOut)
def sync_patient(patient: schemas.PatientCreate, db: Session = Depends(get_db)):
    existing = db.query(models.Patient).filter(models.Patient.user_id == str(patient.user_id)).first()
    if existing:
        for field, value in patient.dict(exclude_unset=True).items():
            setattr(existing, field, str(value) if isinstance(value, type(patient.user_id)) else value)
        db.commit()
        db.refresh(existing)
        return existing

    duplicate_contact = db.query(models.Patient).filter(
        or_(models.Patient.email == patient.email, models.Patient.phone == patient.phone),
        models.Patient.email != None,
        models.Patient.phone != None
    ).first()
    if duplicate_contact:
        raise HTTPException(status_code=400, detail="Email or phone number is already registered.")

    db_data = patient.dict()
    db_data['user_id'] = str(db_data['user_id'])
    db_patient = models.Patient(**db_data)
    db.add(db_patient)
    db.commit()
    db.refresh(db_patient)
    return db_patient

# --- SESSION ENDPOINTS ---
@app.post("/game-sessions/", response_model=schemas.GameSessionOut)
def create_game_session(session: schemas.GameSessionCreate, db: Session = Depends(get_db)):
    patient = db.query(models.Patient).filter(models.Patient.user_id == str(session.user_id)).first()
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found.")
    existing = db.query(models.GameSession).filter(models.GameSession.session_id == str(session.session_id)).first()
    if existing:
        return existing
    db_data = session.dict()
    db_data['session_id'] = str(db_data['session_id'])
    db_data['user_id'] = str(db_data['user_id'])
    db_session = models.GameSession(**db_data)
    db.add(db_session)
    db.commit()
    db.refresh(db_session)
    return db_session

@app.post("/music-sessions/", response_model=schemas.MusicSessionOut)
def create_music_session(session: schemas.MusicSessionCreate, db: Session = Depends(get_db)):
    patient = db.query(models.Patient).filter(models.Patient.user_id == str(session.user_id)).first()
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found.")
    existing = db.query(models.MusicSession).filter(models.MusicSession.session_id == str(session.session_id)).first()
    if existing:
        return existing
    db_data = session.dict()
    db_data['session_id'] = str(db_data['session_id'])
    db_data['user_id'] = str(db_data['user_id'])
    db_session = models.MusicSession(**db_data)
    db.add(db_session)
    db.commit()
    db.refresh(db_session)
    return db_session

# --- REGIONAL MUSIC PLAYS ---
@app.post("/regional-music-plays/", response_model=schemas.RegionalMusicPlayOut)
def sync_regional_music_play(play: schemas.RegionalMusicPlayCreate, db: Session = Depends(get_db)):
    patient = db.query(models.Patient).filter(models.Patient.user_id == str(play.user_id)).first()
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found.")
    existing = db.query(models.RegionalMusicPlay).filter(models.RegionalMusicPlay.play_id == str(play.play_id)).first()
    if existing:
        return existing
    db_data = play.dict()
    db_data['play_id'] = str(db_data['play_id'])
    db_data['user_id'] = str(db_data['user_id'])
    db_play = models.RegionalMusicPlay(**db_data)
    db.add(db_play)
    db.commit()
    db.refresh(db_play)
    return db_play

@app.get("/regional-music-plays/{user_id}")
def get_regional_music_plays(user_id: str, db: Session = Depends(get_db)):
    plays = db.query(models.RegionalMusicPlay).filter(
        models.RegionalMusicPlay.user_id == user_id
    ).order_by(models.RegionalMusicPlay.timestamp.desc()).all()
    return [schemas.RegionalMusicPlayOut.from_orm(p) for p in plays]

@app.get("/regional-music-summary/{user_id}")
def get_regional_music_summary(user_id: str, db: Session = Depends(get_db)):
    plays = db.query(models.RegionalMusicPlay).filter(
        models.RegionalMusicPlay.user_id == user_id
    ).order_by(models.RegionalMusicPlay.timestamp.desc()).all()
    total_duration = sum(p.duration_seconds or 0 for p in plays)
    total_loops = sum(p.loop_count or 0 for p in plays)
    state_durations = {}
    state_loops = {}
    for p in plays:
        state = p.state_name or 'Unknown'
        state_durations[state] = state_durations.get(state, 0) + (p.duration_seconds or 0)
        state_loops[state] = state_loops.get(state, 0) + (p.loop_count or 0)
    most_played_state = max(state_durations, key=state_durations.get) if state_durations else 'None'
    return {
        'total_plays': len(plays),
        'total_duration_seconds': total_duration,
        'total_loops': total_loops,
        'most_played_state': most_played_state,
        'state_durations': state_durations,
        'state_loops': state_loops,
    }

# --- ML MOOD ANALYSIS ---
@app.post("/analyze-mood")
def analyze_mood(
    state_name: str = '',
    song_title: str = '',
    loop_count: int = 0,
    total_duration: float = 0.0,
    audio_path: str = '',
):
    try:
        from audio_ml_service import analyze_song as ml_analyze_song
        if audio_path and os.path.exists(audio_path):
            result = ml_analyze_song(audio_path, loop_count, total_duration)
        else:
            from audio_ml_service import AudioFeatures, get_predictor
            features = AudioFeatures(
                tempo_bpm=80.0 if loop_count <= 1 else 100.0,
                rms_energy_mean=0.03 if total_duration < 60 else 0.06,
                spectral_centroid_mean=1500.0,
            )
            predictor = get_predictor()
            prediction = predictor.predict(features, loop_count, total_duration)
            result = {
                'emotional_state': prediction['emotional_state'],
                'cognitive_response': prediction['cognitive_response'],
                'confidence': prediction['confidence'],
                'arousal_level': prediction['arousal_level'],
                'valence': prediction['valence'],
            }
        return result
    except ImportError:
        from audio_ml_service import AudioFeatures, get_predictor
        features = AudioFeatures(
            tempo_bpm=80.0 if loop_count <= 1 else 100.0,
            rms_energy_mean=0.03 if total_duration < 60 else 0.06,
            spectral_centroid_mean=1500.0,
        )
        predictor = get_predictor()
        prediction = predictor.predict(features, loop_count, total_duration)
        return {
            'emotional_state': prediction['emotional_state'],
            'cognitive_response': prediction['cognitive_response'],
            'confidence': prediction['confidence'],
            'arousal_level': prediction['arousal_level'],
            'valence': prediction['valence'],
        }
    except Exception as e:
        return {
            'emotional_state': 'Relaxed Listening',
            'cognitive_response': 'Processing',
            'confidence': 0.5,
            'arousal_level': 'low',
            'valence': 'neutral',
            'error': str(e),
        }

# --- AI CHATBOT ENDPOINTS ---

@app.post("/caregiver-advisor/", response_model=schemas.ChatResponse)
def caregiver_advisor(request: schemas.ChatRequest):
    try:
        client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))
        response = client.models.generate_content(
            model="gemini-3.5-flash",
            contents=f"You are a compassionate dementia care advisor. The caregiver asks: {request.message}"
        )
        return schemas.ChatResponse(reply=response.text)
    except Exception as e:
        print(f"❌ Caregiver Advisor API Error: {e}")
        return schemas.ChatResponse(
            reply="The AI advisor service is currently experiencing high demand or rate limits. Please try again in a moment."
        )

@app.post("/patient-chat/", response_model=schemas.ChatResponse)
def patient_chat(request: schemas.ChatRequest):
    try:
        client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))
        response = client.models.generate_content(
            model="gemini-3.5-flash",
            contents=(
                "You are a warm, gentle, and comforting daily companion for an elderly person "
                "with cognitive needs. Keep your answers very short, simple, reassuring, "
                "and friendly. The user says: " + request.message
            )
        )
        return schemas.ChatResponse(reply=response.text)
    except Exception as e:
        print(f"❌ Patient Chat API Error: {e}")
        fallback_reply = get_language_fallback(request.message)
        return schemas.ChatResponse(reply=fallback_reply)

# --- VOICE ASSISTANT ---

class VoiceAssistantRequest(BaseModel):
    message: str

class VoiceAssistantResponse(BaseModel):
    action: str
    spoken_response: str

@app.post("/voice-assistant/", response_model=VoiceAssistantResponse)
def voice_assistant(request: VoiceAssistantRequest):
    try:
        api_key=os.getenv("GEMINI_API_KEY")
        if not api_key:
            print("❌ ERROR: GEMINI_API_KEY not found! Check your .env file.")
            raise ValueError("API Key Missing")

        client = genai.Client(api_key=api_key)
        
        
        prompt = f"""
You are a warm, gentle, and empathetic AI voice companion inside a Dementia & Cognitive Care mobile app.

CRITICAL RULES FOR LANGUAGE & SCRIPT:
1. You MUST write the 'spoken_response' in the EXACT SAME LANGUAGE the user used.
2. NATIVE SCRIPT ONLY: If the user speaks Bengali or Hindi (even if they typed in English letters like "kemon acho" or "kaise ho"), you MUST reply using the NATIVE SCRIPT (Bengali: বাংলা লিপি, Hindi: देवनागरी). 
3. NEVER use Romanized English letters for Indian languages. Our Text-to-Speech engine will fail if you do not use native Unicode characters.

Available App Actions:
- "start_memory_game"
- "start_pattern_game"
- "start_song_game"
- "start_photo_game"
- "open_routine"
- "open_music"
- "open_family"
- "open_reminders"
- "none"

User speech: "{request.message}"

Analyze the speech, select the appropriate action, and provide a comforting spoken response strictly following the script rules above.
"""
        response = client.models.generate_content(
            model="gemini-3.5-flash",
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                response_schema=VoiceAssistantResponse,
                temperature=0.3,
            )
        )
        
        data = json.loads(response.text)
        
        return VoiceAssistantResponse(
            action=data.get("action", "none"),
            spoken_response=data.get("spoken_response", "I am here with you.")
        )
        
    except Exception as e:
        print(f"\n--- 🔴 AI ERROR 🔴 ---")
        print(f"Failed to process speech: {request.message}")
        print(f"Error Details: {e}")
        print(f"----------------------\n")
        
        
        fallback_speech = get_language_fallback(request.message)
        
        return VoiceAssistantResponse(
            action="none",
            spoken_response=fallback_speech
        )
    
from gtts import gTTS
from fastapi.responses import StreamingResponse
import io

class SpeechRequest(BaseModel):
    text: str

@app.post("/generate-speech/")
def generate_speech(request: SpeechRequest):
    try:
        
        lang = 'en'
        if re.search(r'[\u0980-\u09FF]', request.text):
            lang = 'bn'  # Bengali
        elif re.search(r'[\u0900-\u097F]', request.text):
            lang = 'hi'  # Hindi

       
        tts = gTTS(text=request.text, lang=lang, slow=False)
        audio_fp = io.BytesIO()
        tts.write_to_fp(audio_fp)
        audio_fp.seek(0)

        
        return StreamingResponse(audio_fp, media_type="audio/mpeg")
        
    except Exception as e:
        print(f"❌ TTS Audio Generation Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))