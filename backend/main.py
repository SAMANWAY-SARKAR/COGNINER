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