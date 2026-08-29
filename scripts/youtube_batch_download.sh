#!/bin/bash
# ============================================================
# YouTube Batch Download for Regional Folk Songs
# ============================================================
# Downloads real folk song audio from YouTube for all
# remaining synthetic placeholder files.
#
# Requirements: yt-dlp, ffmpeg
#   Install: pip install yt-dlp
#   Install: choco install ffmpeg (Windows) / brew install ffmpeg (Mac)
#
# Usage: bash scripts/youtube_batch_download.sh
# ============================================================

OUTPUT_DIR="assets/audio/regional"
LOG_FILE="scripts/download_log.txt"

echo "============================================================"
echo "  Regional Folk Song YouTube Batch Downloader"
echo "  Downloads real audio for 21 remaining synthetic files"
echo "============================================================"
echo ""

# Check if yt-dlp is installed
if ! command -v yt-dlp &> /dev/null; then
    echo "[ERROR] yt-dlp not found. Install it first:"
    echo "  pip install yt-dlp"
    exit 1
fi

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo "[ERROR] ffmpeg not found. Install it first:"
    echo "  Windows: choco install ffmpeg"
    echo "  Mac: brew install ffmpeg"
    echo "  Linux: sudo apt install ffmpeg"
    exit 1
fi

# Function to download a single song
download_song() {
    local state=$1
    local filename=$2
    local search_query=$3
    local output_path="$OUTPUT_DIR/$state/$filename.mp3"

    # Skip if already a real recording (>1MB)
    if [ -f "$output_path" ]; then
        local size=$(stat -c%s "$output_path" 2>/dev/null || stat -f%z "$output_path" 2>/dev/null)
        if [ "$size" -gt 1000000 ]; then
            echo "  [SKIP] $state/$filename.mp3 (already real, ${size} bytes)"
            return 0
        fi
    fi

    echo "  [SEARCH] $search_query"
    echo "         -> $state/$filename.mp3"

    # Search YouTube and download first result as MP3
    yt-dlp \
        --extract-audio \
        --audio-format mp3 \
        --audio-quality 128K \
        --max-downloads 1 \
        --no-playlist \
        --match-filter "duration<600" \
        --output "$output_path" \
        "ytsearch1:$search_query" \
        2>> "$LOG_FILE"

    if [ -f "$output_path" ]; then
        local new_size=$(stat -c%s "$output_path" 2>/dev/null || stat -f%z "$output_path" 2>/dev/null)
        if [ "$new_size" -gt 100000 ]; then
            echo "         -> OK ($((new_size/1024))KB)"
            return 0
        else
            echo "         -> FAILED (file too small)"
            rm -f "$output_path"
            return 1
        fi
    else
        echo "         -> FAILED (no download)"
        return 1
    fi
}

# Initialize log
echo "Download log - $(date)" > "$LOG_FILE"
echo "" >> "$LOG_FILE"

total=0
success=0
failed=0

# ============================================================
# MEGHALAYA (3 songs)
# ============================================================
echo ""
echo "--- MEGHALAYA ---"

download_song "meghalaya" "wangala_drum_song" "Wangala Garo folk song drums Meghalaya traditional 100 drums festival"
total=$((total+1)); [ $? -eq 0 ] && success=$((success+1)) || failed=$((failed+1))

download_song "meghalaya" "laho_dance_folk" "Laho dance folk song Khasi Meghalaya traditional"
total=$((total+1)); [ $? -eq 0 ] && success=$((success+1)) || failed=$((failed+1))

download_song "meghalaya" "doregala_garo_lullaby" "Garo lullaby traditional Meghalaya folk song"
total=$((total+1)); [ $? -eq 0 ] && success=$((success+1)) || failed=$((failed+1))

# ============================================================
# MANIPUR (2 songs)
# ============================================================
echo ""
echo "--- MANIPUR ---"

download_song "manipur" "nupa_pala_dance_song" "Nupa Pala Manipuri folk dance song traditional Ras Lila"
total=$((total+1)); [ $? -eq 0 ] && success=$((success+1)) || failed=$((failed+1))

download_song "manipur" "pena_eshei_lute_song" "Pena Eshei Manipuri folk song Pena instrument traditional"
total=$((total+1)); [ $? -eq 0 ] && success=$((success+1)) || failed=$((failed+1))

# ============================================================
# MIZORAM (5 songs)
# ============================================================
echo ""
echo "--- MIZORAM ---"

download_song "mizoram" "cheraw_bamboo_dance" "Cheraw bamboo dance Mizoram folk traditional music"
total=$((total+1)); [ $? -eq 0 ] && success=$((success+1)) || failed=$((failed+1))

download_song "mizoram" "lengzem_folk_ballad" "Lengzem Mizo folk song traditional ballad Mizoram"
total=$((total+1)); [ $? -eq 0 ] && success=$((success+1)) || failed=$((failed+1))

download_song "mizoram" "chai_lam_celebration" "Chai Lam Mizo celebration song traditional festival Mizoram"
total=$((total+1)); [ $? -eq 0 ] && success=$((success+1)) || failed=$((failed+1))

download_song "mizoram" "sap_tlang_bamboo_grove" "Sap Tlang Mizo folk song bamboo Mizoram traditional"
total=$((total+1)); [ $? -eq 0 ] && success=$((success+1)) || failed=$((failed+1))

download_song "mizoram" "chhawnghnawh_new_year" "Chhawnghnawh Pawl Kut harvest festival Mizo song"
total=$((total+1)); [ $? -eq 0 ] && success=$((success+1)) || failed=$((failed+1))

# ============================================================
# NAGALAND (1 song)
# ============================================================
echo ""
echo "--- NAGALAND ---"

download_song "nagaland" "konyak_headhunters_chant" "Konyak Naga traditional chant ceremony Nagaland folk"
total=$((total+1)); [ $? -eq 0 ] && success=$((success+1)) || failed=$((failed+1))

# ============================================================
# TRIPURA (4 songs)
# ============================================================
echo ""
echo "--- TRIPURA ---"

download_song "tripura" "hojagiri_ritual_tune" "Hojagiri dance Tripura Reang folk traditional"
total=$((total+1)); [ $? -eq 0 ] && success=$((success+1)) || failed=$((failed+1))

download_song "tripura" "goria_puja_folk_song" "Garia Puja folk song Tripura traditional festival"
total=$((total+1)); [ $? -eq 0 ] && success=$((success+1)) || failed=$((failed+1))

download_song "tripura" "maimiti_tripuri_lullaby" "Tripuri lullaby Kokborok folk song traditional"
total=$((total+1)); [ $? -eq 0 ] && success=$((success+1)) || failed=$((failed+1))

download_song "tripura" "jhum_cultivation_song" "Jhum cultivation song Reang tribal Tripura folk"
total=$((total+1)); [ $? -eq 0 ] && success=$((success+1)) || failed=$((failed+1))

# ============================================================
# ARUNACHAL PRADESH (4 songs)
# ============================================================
echo ""
echo "--- ARUNACHAL PRADESH ---"

download_song "arunachal" "nyishi_community_dance" "Nyishi community dance Arunachal Pradesh folk traditional"
total=$((total+1)); [ $? -eq 0 ] && success=$((success+1)) || failed=$((failed+1))

download_song "arunachal" "galo_myoko_festival" "Galo Myoko festival song Arunachal Pradesh traditional"
total=$((total+1)); [ $? -eq 0 ] && success=$((success+1)) || failed=$((failed+1))

download_song "arunachal" "wancho_war_dance" "Wancho war dance chant Arunachal Pradesh Naga folk"
total=$((total+1)); [ $? -eq 0 ] && success=$((success+1)) || failed=$((failed+1))

download_song "arunachal" "monpa_buddhist_chant" "Monpa Buddhist chant Tawang Arunachal Pradesh folk"
total=$((total+1)); [ $? -eq 0 ] && success=$((success+1)) || failed=$((failed+1))

# ============================================================
# SIKKIM (2 songs)
# ============================================================
echo ""
echo "--- SIKKIM ---"

download_song "sikkim" "tamang_selo_rhythm" "Tamang Selo Damphu drum folk song Sikkim traditional"
total=$((total+1)); [ $? -eq 0 ] && success=$((success+1)) || failed=$((failed+1))

download_song "sikkim" "limbu_mundhum_chant" "Limbu Mundhum chant Sikkim folk traditional creation"
total=$((total+1)); [ $? -eq 0 ] && success=$((success+1)) || failed=$((failed+1))

# ============================================================
# SUMMARY
# ============================================================
echo ""
echo "============================================================"
echo "  DOWNLOAD COMPLETE"
echo "  Total: $total songs searched"
echo "  Success: $success"
echo "  Failed: $failed"
echo "============================================================"
echo ""
echo "Checking final status..."

real=0; synth=0
for state in assam meghalaya manipur mizoram nagaland tripura arunachal sikkim; do
  for f in $OUTPUT_DIR/$state/*.mp3; do
    size=$(stat -c%s "$f" 2>/dev/null || stat -f%z "$f" 2>/dev/null)
    if [ "$size" -gt 1000000 ]; then
      real=$((real+1))
    else
      synth=$((synth+1))
    fi
  done
done

echo "  Real recordings: $real / 41"
echo "  Synthetic: $synth / 41"
