import os
from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import or_
import models
import schemas
from database import Base, engine, SessionLocal

Base.metadata.create_all(bind=engine)

app = FastAPI(title="Cogniner Sync API")

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

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


# --- ML MOOD ANALYSIS (calls audio_ml_service internally) ---
@app.post("/analyze-mood")
def analyze_mood(
    state_name: str = '',
    song_title: str = '',
    loop_count: int = 0,
    total_duration: float = 0.0,
    audio_path: str = '',
):
    """
    Predict emotional/cognitive state using the ML pipeline.
    Falls back to rule-based prediction if audio_ml_service is not available.
    """
    try:
        from audio_ml_service import analyze_song as ml_analyze_song
        if audio_path and os.path.exists(audio_path):
            result = ml_analyze_song(audio_path, loop_count, total_duration)
        else:
            # Use rule-based prediction when no audio file is available
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
        # Fallback: rule-based heuristic when ML service is not importable
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