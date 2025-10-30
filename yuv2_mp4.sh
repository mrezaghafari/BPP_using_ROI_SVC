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

# Original YUV source files
ORIG_DIR="/home/resist/MG/PacketWash/2560_1440"
declare -A orig_yuv_files
orig_yuv_files["COD"]="COD-BlackOps4_P1_10s_30fps_2560x1440.yuv"
orig_yuv_files["DEVIL"]="DevilMayCry5_P1_10s_60fps_30fps_2560x1440.yuv"
orig_yuv_files["FORZA"]="ForzaHorizon4_P1_10s_30fps_2560x1440.yuv"
orig_yuv_files["PES"]="PES2019v1_P1_10s_60fps_30fps_2560x1440.yuv"

# ROI and NonROI base paths
BASE_NONROI="/home/resist/MG/PacketWash/h264_over_bpp-main/ICINT/nonROI"
BASE_ROI="/home/resist/MG/PacketWash/h264_over_bpp-main/ICINT/ROI/gblur"

# Quality level mapping
declare -A quality_paths=(
    ["Q3"]="Encoded/*_qp20.yuv"
    ["Q2"]="BPP/*_Th10.yuv"
    ["Q1"]="BPP/*_Th5.yuv"
)

encode_lossless() {
    local input="$1"
    local output="$2"
    local fps="$3"

    if [[ -f "$input" ]]; then
        echo "Encoding to lossless: $output"
        ffmpeg -y -s $RESOLUTION -pix_fmt $PIX_FMT -r "$fps" -i "$input" \
            -c:v libx264 -preset veryslow -crf 0 "$output"
    else
        echo "❌ File not found: $input"
    fi
}

# Encode original videos
for game in "${!orig_yuv_files[@]}"; do
    input_file="$ORIG_DIR/${orig_yuv_files[$game]}"
    output_file="$OUTPUT_DIR/${game}_Original.mp4"
    fps="${frame_rates[$game]}"
    encode_lossless "$input_file" "$output_file" "$fps"
done

# Encode ROI and NonROI at each quality level
for game in "${!orig_yuv_files[@]}"; do
    fps="${frame_rates[$game]}"
    for quality in Q3 Q2 Q1; do
        pattern="${quality_paths[$quality]}"

        # ROI
        roi_dir="$BASE_ROI/$game"
        roi_input=$(find "$roi_dir" -type f -path "*$pattern" | head -n 1)
        roi_output="$OUTPUT_DIR/${game}_ROI_${quality}.mp4"
        encode_lossless "$roi_input" "$roi_output" "$fps"

        # NonROI
        nonroi_dir="$BASE_NONROI/$game"
        nonroi_input=$(find "$nonroi_dir" -type f -path "*$pattern" | head -n 1)
        nonroi_output="$OUTPUT_DIR/${game}_NonROI_${quality}.mp4"
        encode_lossless "$nonroi_input" "$nonroi_output" "$fps"
    done
done

echo "✅ All videos encoded losslessly."
