"""
Regional Nostalgic Music & Cognitive-Emotional Intelligence ML Service
=====================================================================
Extracts audio features from songs using librosa and predicts patient
emotional/cognitive states based on acoustic vectors + playback behavior.

Usage:
    python audio_ml_service.py --audio_file path/to/song.mp3
    python audio_ml_service.py --server  (runs as FastAPI microservice)
"""

import os
import json
import numpy as np
from pathlib import Path
from dataclasses import dataclass, asdict
from typing import Optional

# --- Librosa Audio Feature Extraction ---
try:
    import librosa
    LIBROSA_AVAILABLE = True
except ImportError:
    LIBROSA_AVAILABLE = False
    print("WARNING: librosa not installed. Run: pip install librosa")

# --- ML Model ---
try:
    import joblib
    from sklearn.neural_network import MLPClassifier
    from sklearn.preprocessing import StandardScaler
    SKLEARN_AVAILABLE = True
except ImportError:
    SKLEARN_AVAILABLE = False
    print("WARNING: scikit-learn not installed. Run: pip install scikit-learn")


# ============================================================
# 1. AUDIO FEATURE EXTRACTION (librosa)
# ============================================================

@dataclass
class AudioFeatures:
    """Acoustic features extracted from an audio file."""
    tempo_bpm: float = 0.0
    spectral_centroid_mean: float = 0.0
    spectral_rolloff_mean: float = 0.0
    zero_crossing_rate_mean: float = 0.0
    rms_energy_mean: float = 0.0
    chroma_mean: float = 0.0
    tonnetz_mean: float = 0.0
    mfcc_1: float = 0.0
    mfcc_2: float = 0.0
    mfcc_3: float = 0.0
    mfcc_4: float = 0.0
    mfcc_5: float = 0.0
    duration_seconds: float = 0.0

    def to_vector(self) -> np.ndarray:
        """Convert features to a numpy vector for ML input."""
        return np.array([
            self.tempo_bpm,
            self.spectral_centroid_mean,
            self.spectral_rolloff_mean,
            self.zero_crossing_rate_mean,
            self.rms_energy_mean,
            self.chroma_mean,
            self.tonnetz_mean,
            self.mfcc_1, self.mfcc_2, self.mfcc_3,
            self.mfcc_4, self.mfcc_5,
        ])


def extract_audio_features(audio_path: str) -> AudioFeatures:
    """
    Extract key acoustic vectors from an audio file using librosa.

    Extracted features:
      - Tempo (BPM)
      - Spectral Centroid (brightness/sharpness)
      - Spectral Rolloff (frequency distribution)
      - Zero-Crossing Rate (noise/purity)
      - RMS Energy (intensity)
      - Chroma (pitch/key)
      - Tonnetz (tonal centroid features)
      - MFCCs (Mel-Frequency Cepstral Coefficients)
    """
    if not LIBROSA_AVAILABLE:
        print(f"[SKIP] librosa not available. Returning default features for: {audio_path}")
        return AudioFeatures()

    try:
        y, sr = librosa.load(audio_path, sr=22050, mono=True)
        duration = librosa.get_duration(y=y, sr=sr)

        # Tempo
        tempo, _ = librosa.beat.beat_track(y=y, sr=sr)
        tempo_bpm = float(tempo) if np.isscalar(tempo) else float(tempo[0])

        # Spectral features
        spectral_centroid = librosa.feature.spectral_centroid(y=y, sr=sr)
        spectral_rolloff = librosa.feature.spectral_rolloff(y=y, sr=sr)
        zero_crossing_rate = librosa.feature.zero_crossing_rate(y)
        rms_energy = librosa.feature.rms(y=y)

        # Pitch / Chroma
        chroma = librosa.feature.chroma_stft(y=y, sr=sr)
        tonnetz = librosa.feature.tonnetz(y=librosa.effects.harmonic(y), sr=sr)

        # MFCCs (first 5 coefficients)
        mfccs = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=5)

        features = AudioFeatures(
            tempo_bpm=tempo_bpm,
            spectral_centroid_mean=float(np.mean(spectral_centroid)),
            spectral_rolloff_mean=float(np.mean(spectral_rolloff)),
            zero_crossing_rate_mean=float(np.mean(zero_crossing_rate)),
            rms_energy_mean=float(np.mean(rms_energy)),
            chroma_mean=float(np.mean(chroma)),
            tonnetz_mean=float(np.mean(tonnetz)),
            mfcc_1=float(np.mean(mfccs[0])),
            mfcc_2=float(np.mean(mfccs[1])),
            mfcc_3=float(np.mean(mfccs[2])),
            mfcc_4=float(np.mean(mfccs[3])),
            mfcc_5=float(np.mean(mfccs[4])),
            duration_seconds=duration,
        )
        return features

    except Exception as e:
        print(f"[ERROR] Failed to extract features from {audio_path}: {e}")
        return AudioFeatures()


# ============================================================
# 2. NEURAL NETWORK EMOTION PREDICTOR
# ============================================================

# Emotional/cognitive state labels
EMOTION_STATES = [
    "Calm & Relaxation",
    "Deep Reminiscence",
    "Nostalgic Joy",
    "Heightened Arousal",
    "Melancholy",
    "Soothing Relaxation",
    "Agitation",
    "Restlessness",
]

# Training data: synthetic acoustic profiles mapped to emotional states
# In production, this would be trained on real patient data
TRAINING_DATA = [
    # (tempo, energy, centroid, zcr, label_index)
    # Slow / Low energy / Harmonic → Calm / Deep Reminiscence
    (70, 0.03, 1500, 0.05, 0),   # Calm
    (65, 0.02, 1200, 0.04, 1),   # Deep Reminiscence
    (75, 0.04, 1800, 0.06, 1),   # Deep Reminiscence
    (60, 0.02, 1000, 0.03, 0),   # Calm
    (80, 0.03, 2000, 0.05, 5),   # Soothing Relaxation
    (72, 0.025, 1400, 0.04, 5),  # Soothing Relaxation
    # Medium tempo / Moderate energy → Nostalgic Joy
    (100, 0.06, 2500, 0.08, 2),  # Nostalgic Joy
    (110, 0.07, 2800, 0.09, 2),  # Nostalgic Joy
    (95, 0.05, 2200, 0.07, 2),   # Nostalgic Joy
    (105, 0.065, 2600, 0.085, 2),# Nostalgic Joy
    # Fast / High energy / Rhythmic → Heightened Arousal / Agitation
    (140, 0.12, 3500, 0.15, 3),  # Heightened Arousal
    (150, 0.14, 3800, 0.18, 3),  # Heightened Arousal
    (135, 0.11, 3200, 0.14, 7),  # Restlessness
    (145, 0.13, 3600, 0.16, 6),  # Agitation
    (155, 0.15, 4000, 0.20, 6),  # Agitation
    (130, 0.10, 3000, 0.12, 7),  # Restlessness
    # Slow but melancholic (low centroid, moderate energy)
    (68, 0.04, 1100, 0.06, 4),   # Melancholy
    (72, 0.035, 1300, 0.055, 4), # Melancholy
    (62, 0.03, 900, 0.045, 4),   # Melancholy
    (75, 0.045, 1500, 0.07, 4),  # Melancholy
]


class EmotionPredictor:
    """
    Neural Network (MLP) classifier that maps acoustic features
    and playback behavior to predicted emotional/cognitive states.
    """

    def __init__(self):
        self.model = None
        self.scaler = StandardScaler()
        self.is_trained = False

    def train(self):
        """Train the MLP classifier on synthetic acoustic profiles."""
        if not SKLEARN_AVAILABLE:
            print("[SKIP] scikit-learn not available. Using rule-based fallback.")
            return

        X = np.array([[d[0], d[1], d[2], d[3]] for d in TRAINING_DATA])
        y = np.array([d[4] for d in TRAINING_DATA])

        self.scaler.fit(X)
        X_scaled = self.scaler.transform(X)

        self.model = MLPClassifier(
            hidden_layer_sizes=(32, 16),
            activation='relu',
            max_iter=1000,
            random_state=42,
        )
        self.model.fit(X_scaled, y)
        self.is_trained = True
        print("[ML] Emotion predictor trained successfully on {} samples.".format(len(TRAINING_DATA)))

    def predict(self, features: AudioFeatures, loop_count: int = 0,
                total_duration: float = 0.0) -> dict:
        """
        Predict emotional and cognitive state from audio features
        and playback behavior.

        Returns dict with:
          - emotional_state: predicted emotion label
          - cognitive_response: predicted cognitive assessment
          - confidence: prediction confidence (0-1)
          - arousal_level: low / medium / high
          - valence: negative / neutral / positive
        """
        # Rule-based fallback if sklearn not available
        if not SKLEARN_AVAILABLE or not self.is_trained:
            return self._rule_based_predict(features, loop_count, total_duration)

        # ML prediction
        input_vec = np.array([[
            features.tempo_bpm,
            features.rms_energy_mean,
            features.spectral_centroid_mean,
            features.zero_crossing_rate_mean,
        ]])
        input_scaled = self.scaler.transform(input_vec)

        prediction = self.model.predict(input_scaled)[0]
        probabilities = self.model.predict_proba(input_scaled)[0]
        confidence = float(np.max(probabilities))

        # Adjust prediction based on playback behavior
        adjusted_state = self._adjust_for_playback(
            prediction, loop_count, total_duration
        )

        # Determine arousal and valence
        arousal = self._classify_arousal(features)
        valence = self._classify_valence(features, loop_count)

        return {
            "emotional_state": EMOTION_STATES[adjusted_state],
            "cognitive_response": self._cognitive_assessment(
                adjusted_state, loop_count, total_duration
            ),
            "confidence": round(confidence, 3),
            "arousal_level": arousal,
            "valence": valence,
        }

    def _rule_based_predict(self, features: AudioFeatures,
                            loop_count: int, total_duration: float) -> dict:
        """Fallback rule-based prediction when ML model isn't available."""
        tempo = features.tempo_bpm
        energy = features.rms_energy_mean
        centroid = features.spectral_centroid_mean

        # High loops + long duration → strong resonance
        if loop_count >= 3 and total_duration > 180:
            return {
                "emotional_state": "Deep Reminiscence & Nostalgic Joy",
                "cognitive_response": "Strong Emotional Resonance - Fixation Detected",
                "confidence": 0.85,
                "arousal_level": "medium",
                "valence": "positive",
            }

        if tempo < 80 and energy < 0.05:
            return {
                "emotional_state": "Calm & Relaxation",
                "cognitive_response": "Soothing Engagement - Memory Association",
                "confidence": 0.75,
                "arousal_level": "low",
                "valence": "positive" if loop_count >= 1 else "neutral",
            }

        if tempo > 130 and energy > 0.1:
            if loop_count >= 2:
                return {
                    "emotional_state": "Heightened Arousal & Restlessness",
                    "cognitive_response": "Active Processing - High Energy State",
                    "confidence": 0.70,
                    "arousal_level": "high",
                    "valence": "neutral",
                }
            return {
                "emotional_state": "Nostalgic Joy",
                "cognitive_response": "Engaged & Alert",
                "confidence": 0.65,
                "arousal_level": "medium",
                "valence": "positive",
            }

        if centroid < 1500 and loop_count >= 1:
            return {
                "emotional_state": "Deep Reminiscence",
                "cognitive_response": "Active Engagement & Memory Association",
                "confidence": 0.72,
                "arousal_level": "low",
                "valence": "positive",
            }

        return {
            "emotional_state": "Relaxed Listening",
            "cognitive_response": "Processing New Stimulus",
            "confidence": 0.60,
            "arousal_level": "low",
            "valence": "neutral",
        }

    def _adjust_for_playback(self, base_state: int,
                             loop_count: int, total_duration: float) -> int:
        """Adjust emotional state based on repeated listening behavior."""
        # Repeated looping signals stronger emotional resonance
        if loop_count >= 3:
            if base_state in (0, 5):  # Calm/Soothing → Deep Reminiscence
                return 1  # Deep Reminiscence
            if base_state == 2:  # Nostalgic Joy → stronger
                return 2  # Stay Nostalgic Joy

        if loop_count >= 2 and total_duration > 120:
            return 2  # Nostalgic Joy (strong engagement)

        return base_state

    def _classify_arousal(self, features: AudioFeatures) -> str:
        if features.tempo_bpm > 120 and features.rms_energy_mean > 0.08:
            return "high"
        elif features.tempo_bpm > 90:
            return "medium"
        return "low"

    def _classify_valence(self, features: AudioFeatures, loop_count: int) -> str:
        if loop_count >= 2:
            return "positive"
        if features.tempo_bpm > 100 and features.spectral_centroid_mean > 2000:
            return "positive"
        if features.tempo_bpm < 70 and features.rms_energy_mean < 0.03:
            return "neutral"
        return "neutral"

    def _cognitive_assessment(self, emotion_state: int,
                              loop_count: int, total_duration: float) -> str:
        assessments = {
            0: "Soothing Engagement - Calm cognitive processing",
            1: "Deep Reminiscence - Strong memory activation detected",
            2: "Active Nostalgia - Positive memory recall in progress",
            3: "Heightened Arousal - Alert and energized cognitive state",
            4: "Melancholic Processing - Reflective cognitive engagement",
            5: "Relaxed Cognitive State - Restful neural engagement",
            6: "Agitation Detected - Monitor for comfort needs",
            7: "Restlessness - Consider calming music transition",
        }
        base = assessments.get(emotion_state, "Processing")

        if loop_count >= 3:
            base += " | Strong fixation - emotional anchor detected"
        elif loop_count >= 1:
            base += " | Active engagement - returning to familiar stimuli"

        return base


# ============================================================
# 3. COMBINED PIPELINE
# ============================================================

# Singleton predictor instance
_predictor: Optional[EmotionPredictor] = None


def get_predictor() -> EmotionPredictor:
    global _predictor
    if _predictor is None:
        _predictor = EmotionPredictor()
        _predictor.train()
    return _predictor


def analyze_song(audio_path: str, loop_count: int = 0,
                 total_duration: float = 0.0) -> dict:
    """
    Full analysis pipeline: extract features → predict emotion/cognitive state.

    Args:
        audio_path: Path to the audio file
        loop_count: Number of times the patient looped this track
        total_duration: Total seconds the patient listened

    Returns:
        dict with audio_features, emotional_state, cognitive_response
    """
    features = extract_audio_features(audio_path)
    predictor = get_predictor()
    prediction = predictor.predict(features, loop_count, total_duration)

    return {
        "audio_features": asdict(features),
        "emotional_state": prediction["emotional_state"],
        "cognitive_response": prediction["cognitive_response"],
        "confidence": prediction["confidence"],
        "arousal_level": prediction["arousal_level"],
        "valence": prediction["valence"],
        "duration_seconds": features.duration_seconds,
    }


# ============================================================
# 4. FASTAPI MICROSERVICE
# ============================================================

def create_app():
    """Create FastAPI app for the ML service."""
    try:
        from fastapi import FastAPI, UploadFile, File, Form
        from fastapi.middleware.cors import CORSMiddleware
    except ImportError:
        print("FastAPI not installed. Run: pip install fastapi uvicorn")
        return None

    app = FastAPI(title="Cogniner Audio ML Service")
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.get("/")
    def root():
        return {"status": "Audio ML Service running", "librosa": LIBROSA_AVAILABLE, "sklearn": SKLEARN_AVAILABLE}

    @app.post("/analyze")
    async def analyze(
        audio: UploadFile = File(...),
        loop_count: int = Form(0),
        total_duration: float = Form(0.0),
    ):
        # Save uploaded file temporarily
        temp_path = Path(f"/tmp/{audio.filename}")
        with open(temp_path, "wb") as f:
            content = await audio.read()
            f.write(content)

        result = analyze_song(str(temp_path), loop_count, total_duration)

        # Cleanup
        temp_path.unlink(missing_ok=True)

        return result

    @app.post("/analyze-path")
    def analyze_path(
        audio_path: str = Form(...),
        loop_count: int = Form(0),
        total_duration: float = Form(0.0),
    ):
        if not os.path.exists(audio_path):
            return {"error": f"File not found: {audio_path}"}
        return analyze_song(audio_path, loop_count, total_duration)

    return app


# ============================================================
# 5. CLI ENTRY POINT
# ============================================================

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Audio ML Service for Cogniner")
    parser.add_argument("--audio_file", type=str, help="Path to audio file to analyze")
    parser.add_argument("--loop_count", type=int, default=0, help="Number of loops")
    parser.add_argument("--total_duration", type=float, default=0.0, help="Total listening seconds")
    parser.add_argument("--server", action="store_true", help="Run as FastAPI server")
    parser.add_argument("--port", type=int, default=8001, help="Server port")
    args = parser.parse_args()

    if args.server:
        app = create_app()
        if app:
            import uvicorn
            print(f"Starting Audio ML Service on port {args.port}...")
            uvicorn.run(app, host="0.0.0.0", port=args.port)
    elif args.audio_file:
        result = analyze_song(args.audio_file, args.loop_count, args.total_duration)
        print(json.dumps(result, indent=2))
    else:
        parser.print_help()
        print("\nExamples:")
        print("  python audio_ml_service.py --audio_file song.mp3")
        print("  python audio_ml_service.py --server --port 8001")
