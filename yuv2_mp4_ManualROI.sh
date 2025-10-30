#!/bin/bash

set -e

# Output directory
OUTPUT_DIR="/home/resist/MG/PacketWash/h264_over_bpp-main/ICINT/static/videos"
mkdir -p "$OUTPUT_DIR"

# Resolution and pixel format
RESOLUTION="2560x1440"
PIX_FMT="yuv420p"

# Frame rate per game
declare -A frame_rates
frame_rates["COD"]=30
frame_rates["DEVIL"]=30
frame_rates["FORZA"]=30
frame_rates["PES"]=30

# BPP base path
BASE_BITEXT="/home/resist/MG/PacketWash/h264_over_bpp-main/ICINT/ManualROI/gblur"

# BPP QL mapping
declare -A bitext_suffixes
bitext_suffixes["QL1"]="pw_roi_Th5"
bitext_suffixes["QL2"]="pw_roi_Th10"

encode_lossless() {
    local input="$1"
    local output="$2"
    local fps="$3"

    if [[ -f "$input" ]]; then
        echo "🎬 Encoding: $input → $output"
        ffmpeg -y -s $RESOLUTION -pix_fmt $PIX_FMT -r "$fps" -i "$input" \
            -c:v libx264 -preset veryslow -crf 0 "$output"
    else
        echo "❌ File not found: $input"
    fi
}

# Encode BPP decoded YUVs
for game in "${!frame_rates[@]}"; do
    fps="${frame_rates[$game]}"
    for ql in "QL2" "QL1"; do
        suffix="${bitext_suffixes[$ql]}"
        input_file="${BASE_BITEXT}/${game}/BPP/rec_${suffix}.yuv"
        output_file="${OUTPUT_DIR}/${game}_ManualROI_${ql}.mp4"
        encode_lossless "$input_file" "$output_file" "$fps"
    done
done

echo "✅ BPP lossless encoding completed."
