# Regional Nostalgic Music — Audio Setup Guide

## Overview

The Regional Nostalgic Music module contains **41 folk songs** from 8 Northeast Indian
states, each with a unique audio path. The app expects one `.mp3` file per song at
the exact path listed below.

---

## Quick Start: Generate Placeholder Audio

Each song needs a **distinct** audio file so patients hear different tracks.

```bash
# Install dependencies
pip install numpy scipy

# Generate unique placeholder audio (each song sounds different)
python scripts/generate_regional_placeholders.py
```

This creates 41 unique MP3 files under `assets/audio/regional/` with different
frequencies, rhythms, and durations — so every song sounds distinct.

> **Requires:** `ffmpeg` for MP3 output. Install via:
> - Windows: `choco install ffmpeg` or `winget install ffmpeg`
> - macOS: `brew install ffmpeg`
> - Linux: `sudo apt install ffmpeg`

---

## Adding Real Folk Recordings

### Sourcing Authentic Songs

For each song below, obtain a genuine `.mp3` recording (ideally 1960s–1970s era)
and place it at the exact path listed.

**Recommended sources:**
- **National Archives of India** — Folk music recordings division
- **Sangeet Natak Akademi** — Archives of Indian folk performing arts
- **North East Zone Cultural Centre (NEZCC)** — Dimapur, Nagaland
- **State Kala Academies** — Each NE state has one
- **Doordarshan Archives** — Regional folk broadcast recordings
- **Indian Council for Cultural Relations (ICCR)**
- **Internet Archive** (archive.org) — Search for public domain folk recordings
- **YouTube → yt-dlp** — Convert with permission for personal/educational use

### File Naming Convention

```
assets/audio/regional/{state}/{song_slug}.mp3
```

Example: `assets/audio/regional/assam/bihu_naam_spring_harvest.mp3`

---

## Complete Song List with Paths

### 🟢 ASSAM (6 songs)

| # | Song Title | Artist | Year | File Path |
|---|-----------|--------|------|-----------|
| 1 | Bihu Naam - Spring Harvest Song | Traditional Bihu Folk | 1965 | `audio/regional/assam/bihu_naam_spring_harvest.mp3` |
| 2 | Tokari Geet - Devotional Ballad | Assamese Folk Artists | 1962 | `audio/regional/assam/tokari_geet_devotional.mp3` |
| 3 | Goalpariya Lokogeet - Boatman's Song | Goalpara Region Folk | 1968 | `audio/regional/assam/goalpariya_lokogeet_boatman.mp3` |
| 4 | Bodo Bwisagu Folk Tune | Bodo Tribal Artists | 1966 | `audio/regional/assam/bodo_bwisagu_folk.mp3` |
| 5 | Jhumur Nritya Geet | Tea Garden Folk | 1970 | `audio/regional/assam/jhumur_nritya_geet.mp3` |
| 6 | Ojapali Traditional Chant | Assamese Traditional | 1963 | `audio/regional/assam/ojapali_traditional_chant.mp3` |

### 🔵 MEGHALAYA (5 songs)

| # | Song Title | Artist | Year | File Path |
|---|-----------|--------|------|-----------|
| 1 | Phawar - Khasi Love Ballad | Khasi Folk Tradition | 1964 | `audio/regional/meghalaya/phawar_khasi_love_ballad.mp3` |
| 2 | Wangala Drum Song | Garo Tribal Artists | 1967 | `audio/regional/meghalaya/wangala_drum_song.mp3` |
| 3 | Laho Dance Folk Tune | Khasi Youth Folk | 1969 | `audio/regional/meghalaya/laho_dance_folk.mp3` |
| 4 | Doregala - Garo Lullaby | Garo Mothers' Folk | 1961 | `audio/regional/meghalaya/doregala_garo_lullaby.mp3` |
| 5 | Nongkrem Festival Song | Khasi Traditional | 1966 | `audio/regional/meghalaya/nongkrem_festival_song.mp3` |

### 🟠 MANIPUR (5 songs)

| # | Song Title | Artist | Year | File Path |
|---|-----------|--------|------|-----------|
| 1 | Lai Haraoba Ritual Song | Meitei Traditional | 1963 | `audio/regional/manipur/lai_haraoba_ritual_song.mp3` |
| 2 | Khullang Eshei - Martial Ballad | Manipuri Folk | 1965 | `audio/regional/manipur/khullang_eshei_martial.mp3` |
| 3 | Pena Eshei - Lute Song | Pena Folk Artists | 1968 | `audio/regional/manipur/pena_eshei_lute_song.mp3` |
| 4 | Nupa Pala - Dance Song | Manipuri Classical Folk | 1962 | `audio/regional/manipur/nupa_pala_dance_song.mp3` |
| 5 | Thabal Chongba Moon Dance | Meitei Youth Folk | 1970 | `audio/regional/manipur/thabal_chongba_moon_dance.mp3` |

### 🟣 MIZORAM (5 songs)

| # | Song Title | Artist | Year | File Path |
|---|-----------|--------|------|-----------|
| 1 | Cheraw Bamboo Dance Rhythm | Mizo Traditional | 1964 | `audio/regional/mizoram/cheraw_bamboo_dance.mp3` |
| 2 | Lengzem - Mizo Folk Ballad | Mizo Folk Artists | 1967 | `audio/regional/mizoram/lengzem_folk_ballad.mp3` |
| 3 | Chai Lam - Celebration Song | Mizo Community | 1969 | `audio/regional/mizoram/chai_lam_celebration.mp3` |
| 4 | Sap Tlang - Bamboo Grove Song | Mizo Hill Folk | 1963 | `audio/regional/mizoram/sap_tlang_bamboo_grove.mp3` |
| 5 | Chhawnghnawh - New Year Song | Mizo Traditional | 1966 | `audio/regional/mizoram/chhawnghnawh_new_year.mp3` |

### 🔴 NAGALAND (5 songs)

| # | Song Title | Artist | Year | File Path |
|---|-----------|--------|------|-----------|
| 1 | Angami War Chant | Angami Tribal | 1962 | `audio/regional/nagaland/angami_war_chant.mp3` |
| 2 | Ao Morung Folk Song | Ao Naga Artists | 1965 | `audio/regional/nagaland/ao_morung_folk_song.mp3` |
| 3 | Tenyidie Harvest Song | Angami Folk | 1968 | `audio/regional/nagaland/tenyidie_harvest_song.mp3` |
| 4 | Sekrenyi Festival Tune | Kohima Region Folk | 1964 | `audio/regional/nagaland/sekrenyi_festival_tune.mp3` |
| 5 | Konyak Headhunters' Chant | Konyak Tribal | 1960 | `audio/regional/nagaland/konyak_headhunters_chant.mp3` |

### 🟤 TRIPURA (5 songs)

| # | Song Title | Artist | Year | File Path |
|---|-----------|--------|------|-----------|
| 1 | Dhamail Dance Song | Tripuri Tribal | 1966 | `audio/regional/tripura/dhamail_dance_song.mp3` |
| 2 | Hojagiri Ritual Tune | Reang Community | 1963 | `audio/regional/tripura/hojagiri_ritual_tune.mp3` |
| 3 | Goria Puja Folk Song | Tripuri Farmers | 1968 | `audio/regional/tripura/goria_puja_folk_song.mp3` |
| 4 | Maimiti - Tripuri Lullaby | Tripuri Mothers' Folk | 1961 | `audio/regional/tripura/maimiti_tripuri_lullaby.mp3` |
| 5 | Jhum Cultivation Song | Reang Tribal | 1970 | `audio/regional/tripura/jhum_cultivation_song.mp3` |

### 🟣 ARUNACHAL PRADESH (5 songs)

| # | Song Title | Artist | Year | File Path |
|---|-----------|--------|------|-----------|
| 1 | Apatani Rice Song | Apatani Tribal | 1964 | `audio/regional/arunachal/apatani_rice_song.mp3` |
| 2 | Nyishi Community Dance | Nyishi Artists | 1967 | `audio/regional/arunachal/nyishi_community_dance.mp3` |
| 3 | Galo Myoko Festival Tune | Galo Folk | 1969 | `audio/regional/arunachal/galo_myoko_festival.mp3` |
| 4 | Wancho War Dance Chant | Wancho Tribal | 1962 | `audio/regional/arunachal/wancho_war_dance.mp3` |
| 5 | Monpa Buddhist Chant | Tawang Region | 1965 | `audio/regional/arunachal/monpa_buddhist_chant.mp3` |

### 🔵 SIKKIM (5 songs)

| # | Song Title | Artist | Year | File Path |
|---|-----------|--------|------|-----------|
| 1 | Lepcha Tendong Song | Lepcha Traditional | 1963 | `audio/regional/sikkim/lepcha_tendong_song.mp3` |
| 2 | Bhutia Losar Folk Tune | Bhutia Community | 1966 | `audio/regional/sikkim/bhutia_losar_folk.mp3` |
| 3 | Chaam Dance Chant | Sikkimese Monks | 1968 | `audio/regional/sikkim/chaam_dance_chant.mp3` |
| 4 | Tamang Selo Rhythm | Tamang Folk | 1965 | `audio/regional/sikkim/tamang_selo_rhythm.mp3` |
| 5 | Limbu Mundhum Chant | Limbu Tribal | 1961 | `audio/regional/sikkim/limbu_mundhum_chant.mp3` |

---

## Audio Requirements

- **Format:** MP3 (preferred) or WAV
- **Bitrate:** 128kbps MP3 minimum
- **Sample Rate:** 22050 Hz or 44100 Hz
- **Channels:** Mono or Stereo
- **Duration:** Any length (3–15 minutes typical for folk songs)
- **Quality:** Clear enough for dementia patients to recognize melodies

## How the App Uses These Files

1. Patient opens **Music Therapy → Regional Music**
2. Selects a **state** (e.g., Assam)
3. Taps a **song** (e.g., "Bihu Naam - Spring Harvest Song")
4. App loads `AssetSource('audio/regional/assam/bihu_naam_spring_harvest.mp3')`
5. Plays through the dementia-friendly player with loop/tracking
6. Duration and loop data saved to `regional_music_plays` database table
7. ML service predicts emotional/cognitive state from acoustic features

## Copyright & Licensing

> ⚠️ **Important:** Ensure you have proper licensing or permission before adding
> copyrighted folk recordings. Many traditional folk songs are in the public domain,
> but specific recordings may be copyrighted. Consider:
> - Using Creative Commons licensed recordings
> - Obtaining written permission from recording artists/estates
> - Recording new performances with community consent
> - Using government archival recordings with proper attribution
