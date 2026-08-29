#!/usr/bin/env python3
"""
Generate Unique Placeholder Audio Files for Regional Folk Songs
================================================================
Creates distinct MP3 files for each of the 41 regional folk songs
using different frequencies, durations, and rhythmic patterns so
each song sounds unique until real recordings are added.

Requirements:
    pip install numpy scipy

Usage:
    python scripts/generate_regional_placeholders.py

Each song gets a unique signature based on:
  - State (base frequency range)
  - Song position (pitch variation)
  - Era year (subtle modulation)
"""

import os
import struct
import math
import wave
import subprocess
from pathlib import Path

# Output directory
OUTPUT_DIR = Path("assets/audio/regional")

# All songs with their file paths and metadata
SONGS = [
    # ========== ASSAM ==========
    {"path": "assam/bihu_naam_spring_harvest.mp3", "freq": 262, "dur": 8, "bpm": 120},
    {"path": "assam/tokari_geet_devotional.mp3", "freq": 220, "dur": 10, "bpm": 80},
    {"path": "assam/goalpariya_lokogeet_boatman.mp3", "freq": 294, "dur": 9, "bpm": 100},
    {"path": "assam/bodo_bwisagu_folk.mp3", "freq": 330, "dur": 7, "bpm": 140},
    {"path": "assam/jhumur_nritya_geet.mp3", "freq": 349, "dur": 8, "bpm": 130},
    {"path": "assam/ojapali_traditional_chant.mp3", "freq": 196, "dur": 12, "bpm": 60},
    # ========== MEGHALAYA ==========
    {"path": "meghalaya/phawar_khasi_love_ballad.mp3", "freq": 277, "dur": 10, "bpm": 90},
    {"path": "meghalaya/wangala_drum_song.mp3", "freq": 311, "dur": 8, "bpm": 150},
    {"path": "meghalaya/laho_dance_folk.mp3", "freq": 370, "dur": 7, "bpm": 160},
    {"path": "meghalaya/doregala_garo_lullaby.mp3", "freq": 185, "dur": 14, "bpm": 55},
    {"path": "meghalaya/nongkrem_festival_song.mp3", "freq": 247, "dur": 11, "bpm": 85},
    # ========== MANIPUR ==========
    {"path": "manipur/lai_haraoba_ritual_song.mp3", "freq": 233, "dur": 12, "bpm": 70},
    {"path": "manipur/khullang_eshei_martial.mp3", "freq": 349, "dur": 8, "bpm": 135},
    {"path": "manipur/pena_eshei_lute_song.mp3", "freq": 262, "dur": 10, "bpm": 95},
    {"path": "manipur/nupa_pala_dance_song.mp3", "freq": 392, "dur": 9, "bpm": 125},
    {"path": "manipur/thabal_chongba_moon_dance.mp3", "freq": 330, "dur": 8, "bpm": 115},
    # ========== MIZORAM ==========
    {"path": "mizoram/cheraw_bamboo_dance.mp3", "freq": 311, "dur": 7, "bpm": 145},
    {"path": "mizoram/lengzem_folk_ballad.mp3", "freq": 220, "dur": 11, "bpm": 75},
    {"path": "mizoram/chai_lam_celebration.mp3", "freq": 370, "dur": 8, "bpm": 155},
    {"path": "mizoram/sap_tlang_bamboo_grove.mp3", "freq": 196, "dur": 10, "bpm": 65},
    {"path": "mizoram/chhawnghnawh_new_year.mp3", "freq": 349, "dur": 9, "bpm": 140},
    # ========== NAGALAND ==========
    {"path": "nagaland/angami_war_chant.mp3", "freq": 165, "dur": 10, "bpm": 110},
    {"path": "nagaland/ao_morung_folk_song.mp3", "freq": 247, "dur": 9, "bpm": 90},
    {"path": "nagaland/tenyidie_harvest_song.mp3", "freq": 294, "dur": 8, "bpm": 100},
    {"path": "nagaland/sekrenyi_festival_tune.mp3", "freq": 330, "dur": 11, "bpm": 80},
    {"path": "nagaland/konyak_headhunters_chant.mp3", "freq": 147, "dur": 12, "bpm": 70},
    # ========== TRIPURA ==========
    {"path": "tripura/dhamail_dance_song.mp3", "freq": 330, "dur": 8, "bpm": 130},
    {"path": "tripura/hojagiri_ritual_tune.mp3", "freq": 220, "dur": 10, "bpm": 75},
    {"path": "tripura/goria_puja_folk_song.mp3", "freq": 262, "dur": 9, "bpm": 95},
    {"path": "tripura/maimiti_tripuri_lullaby.mp3", "freq": 175, "dur": 14, "bpm": 50},
    {"path": "tripura/jhum_cultivation_song.mp3", "freq": 294, "dur": 8, "bpm": 110},
    # ========== ARUNACHAL PRADESH ==========
    {"path": "arunachal/apatani_rice_song.mp3", "freq": 262, "dur": 10, "bpm": 85},
    {"path": "arunachal/nyishi_community_dance.mp3", "freq": 349, "dur": 8, "bpm": 140},
    {"path": "arunachal/galo_myoko_festival.mp3", "freq": 247, "dur": 11, "bpm": 75},
    {"path": "arunachal/wancho_war_dance.mp3", "freq": 196, "dur": 9, "bpm": 120},
    {"path": "arunachal/monpa_buddhist_chant.mp3", "freq": 165, "dur": 14, "bpm": 55},
    # ========== SIKKIM ==========
    {"path": "sikkim/lepcha_tendong_song.mp3", "freq": 277, "dur": 10, "bpm": 80},
    {"path": "sikkim/bhutia_losar_folk.mp3", "freq": 311, "dur": 9, "bpm": 100},
    {"path": "sikkim/chaam_dance_chant.mp3", "freq": 220, "dur": 12, "bpm": 70},
    {"path": "sikkim/tamang_selo_rhythm.mp3", "freq": 370, "dur": 8, "bpm": 135},
    {"path": "sikkim/limbu_mundhum_chant.mp3", "freq": 185, "dur": 14, "bpm": 50},
]


def generate_wav_bytes(freq, duration_sec, bpm, sample_rate=22050):
    """
    Generate a unique WAV byte array with a distinctive rhythmic pattern.
    Each song gets:
      - A base tone at its unique frequency
      - Rhythmic pulsing at its BPM
      - Gentle harmonic overtones for character
      - Fade in/out for smooth listening
    """
    num_samples = int(sample_rate * duration_sec)
    samples = []

    beat_interval = 60.0 / bpm  # seconds per beat

    for i in range(num_samples):
        t = i / sample_rate

        # Base tone
        base = math.sin(2 * math.pi * freq * t)

        # Soft harmonic overtone (gives character)
        harmonic = 0.3 * math.sin(2 * math.pi * freq * 1.5 * t)

        # Rhythmic pulse (amplitude modulation at BPM)
        beat_phase = (t % beat_interval) / beat_interval
        # Sharp attack, gentle decay per beat
        if beat_phase < 0.1:
            pulse = 1.0
        else:
            pulse = max(0.3, 1.0 - (beat_phase - 0.1) * 1.5)

        # Combine
        sample = (base + harmonic) * pulse * 0.4

        # Fade in (first 0.5s) and fade out (last 0.5s)
        if t < 0.5:
            sample *= t / 0.5
        elif t > duration_sec - 0.5:
            sample *= (duration_sec - t) / 0.5

        # Clamp to [-1, 1]
        sample = max(-1.0, min(1.0, sample))
        samples.append(sample)

    return samples, sample_rate


def samples_to_wav_bytes(samples, sample_rate):
    """Convert float samples to WAV format bytes."""
    num_samples = len(samples)
    # Convert to 16-bit PCM
    pcm_data = b''
    for s in samples:
        val = int(s * 32767)
        pcm_data += struct.pack('<h', max(-32768, min(32767, val)))

    # WAV header
    data_size = len(pcm_data)
    header = struct.pack(
        '<4sI4s4sIHHIIHH4sI',
        b'RIFF',
        36 + data_size,
        b'WAVE',
        b'fmt ',
        16,  # chunk size
        1,   # PCM format
        1,   # mono
        sample_rate,
        sample_rate * 2,  # byte rate
        2,   # block align
        16,  # bits per sample
        b'data',
        data_size,
    )
    return header + pcm_data


def convert_wav_to_mp3(wav_path, mp3_path):
    """Convert WAV to MP3 using ffmpeg (if available) or lame."""
    for cmd in [
        ['ffmpeg', '-y', '-i', str(wav_path), '-b:a', '128k', str(mp3_path)],
        ['lame', '-b', '128', str(wav_path), str(mp3_path)],
    ]:
        try:
            result = subprocess.run(cmd, capture_output=True, timeout=30)
            if result.returncode == 0:
                return True
        except (FileNotFoundError, subprocess.TimeoutExpired):
            continue
    return False


def main():
    print("=" * 60)
    print("  Regional Folk Song Placeholder Generator")
    print("  Generates unique audio files for each of 41 songs")
    print("=" * 60)
    print()

    import tempfile
    wav_dir = Path(tempfile.gettempdir()) / "regional_wav"
    wav_dir.mkdir(exist_ok=True)

    created = 0
    wav_only = 0

    for song in SONGS:
        mp3_path = OUTPUT_DIR / song["path"]
        mp3_path.parent.mkdir(parents=True, exist_ok=True)

        if mp3_path.exists():
            print(f"  [SKIP] {song['path']} (already exists)")
            created += 1
            continue

        print(f"  [GEN]  {song['path']}  freq={song['freq']}Hz  dur={song['dur']}s  bpm={song['bpm']}")

        # Generate unique WAV
        samples, sr = generate_wav_bytes(song["freq"], song["dur"], song["bpm"])
        wav_bytes = samples_to_wav_bytes(samples, sr)

        wav_path = wav_dir / song["path"].replace(".mp3", ".wav")
        wav_path.parent.mkdir(parents=True, exist_ok=True)
        with open(wav_path, "wb") as f:
            f.write(wav_bytes)

        # Try to convert to MP3
        if convert_wav_to_mp3(wav_path, mp3_path):
            print(f"         -> MP3 created")
            created += 1
        else:
            # If no converter, save as WAV with .mp3 extension won't work,
            # so save the WAV and note it
            print(f"         -> ffmpeg/lame not found, saving as WAV")
            wav_final = mp3_path.with_suffix(".wav")
            with open(wav_final, "wb") as f:
                f.write(wav_bytes)
            wav_only += 1

        # Cleanup temp WAV
        wav_path.unlink(missing_ok=True)

    # Cleanup
    wav_dir.rmdir()

    print()
    print(f"  Done! {created} MP3 files created")
    if wav_only > 0:
        print(f"  {wav_only} files saved as WAV (install ffmpeg for MP3)")
    print()
    print("  To replace with real folk recordings:")
    print("  1. Obtain authentic .mp3 files for each song")
    print("  2. Place them at the exact path shown above")
    print("  3. The app will automatically play the real recordings")
    print()


if __name__ == "__main__":
    main()
