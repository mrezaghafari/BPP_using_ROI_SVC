#!/bin/bash

output_file="all_results.csv"
echo "Game,Bitrate,PSNR,SSIM,VMAF,LPIPS" > "$output_file"

# Base directory (only ManualROI now)
base_manualroi="/home/resist/MG/PacketWash/h264_over_bpp-main/ICINT/ManualROI/gblur"
original_yuv_dir="/home/resist/MG/PacketWash/2560_1440"

# VMAF config
VMAF_TOOL_PATH="/home/resist/MG/vmaf-3.0.0/libvmaf/build/tools/vmaf"
VMAF_MODEL_PATH="path=/home/resist/MG/vmaf-3.0.0/model/vmaf_4k_v0.6.1.json"

# LPIPS config
LPIPS_SCRIPT_PATH="/home/resist/MG/PacketWash/h264_over_bpp-main/ICINT/run_lpips.py"

# Games list
games=("COD" "DEVIL" "FORZA" "PES")

# Quality levels and corresponding path suffixes
quality_levels=("3" "2" "1")
bitstream_suffixes=("Encoded/*.264" "BPP/*_Th10.264" "BPP/*_Th5.264")
decoded_yuv_suffixes=("Encoded/*_qp20.yuv" "BPP/*_Th10.yuv" "BPP/*_Th5.yuv")

# Original YUV filenames
declare -A orig_yuv_files
orig_yuv_files["COD"]="COD-BlackOps4_P1_10s_30fps_2560x1440.yuv"
orig_yuv_files["DEVIL"]="DevilMayCry5_P1_10s_60fps_30fps_2560x1440.yuv"
orig_yuv_files["FORZA"]="ForzaHorizon4_P1_10s_30fps_2560x1440.yuv"
orig_yuv_files["PES"]="PES2019v1_P1_10s_60fps_30fps_2560x1440.yuv"

RESOLUTION="2560x1440"

# Function to extract bitrate
get_bitrate() {
    bitrate_output=$(python3 ~/MG/PacketWash/mycode/calculate_bitrate.py -f $1 2>/dev/null)
    bitrate_line=$(echo "$bitrate_output" | grep "Bitrate BL+EN1+EN2")
    bitrate_value=$(echo "$bitrate_line" | grep -oP 'Bitrate BL\+EN1\+EN2:\s+\K[0-9.]+')
    echo "$bitrate_value"
}

# Start loop (only ManualROI)
for game in "${games[@]}"; do
    original_yuv_file="${original_yuv_dir}/${orig_yuv_files[$game]}"
    base_path="$base_manualroi/$game"

    for i in "${!quality_levels[@]}"; do
        ql="${quality_levels[$i]}"
        bit_suffix="${bitstream_suffixes[$i]}"
        yuv_suffix="${decoded_yuv_suffixes[$i]}"

        bitstream_path="$base_path/$bit_suffix"
        decoded_yuv_file=$(ls $base_path/$yuv_suffix 2>/dev/null | head -n 1)

        row_name="${game} - ManualROI - QL${ql}"
        echo "▶ Processing: $row_name"

        # Get bitrate
        echo "  ↪ Calculating bitrate from: $bitstream_path"
        bitrate=$(get_bitrate "$bitstream_path")

        # Default values
        PSNR_VALUE="NA"
        SSIM_VALUE="NA"
        VMAF_AVG="NA"
        LPIPS_VALUE="NA"

        if [[ -f "$decoded_yuv_file" && -f "$original_yuv_file" ]]; then
            echo "  ↪ Decoded YUV: $decoded_yuv_file"
            echo "  ↪ Original YUV: $original_yuv_file"

            # PSNR
            echo "    • Computing PSNR..."
            PSNR_OUTPUT=$(ffmpeg -s "$RESOLUTION" -i "$decoded_yuv_file" -s "$RESOLUTION" -i "$original_yuv_file" -lavfi "psnr" -f null - 2>&1)
            PSNR_VALUE=$(echo "$PSNR_OUTPUT" | grep -oP '\[Parsed_psnr_0.*?\] PSNR .*? average:\K[0-9\.]+')

            # SSIM
            echo "    • Computing SSIM..."
            SSIM_OUTPUT=$(ffmpeg -s "$RESOLUTION" -i "$decoded_yuv_file" -s "$RESOLUTION" -i "$original_yuv_file" -lavfi "ssim" -f null - 2>&1)
            SSIM_VALUE=$(echo "$SSIM_OUTPUT" | grep -oP 'All:\K[0-9\.]+')

            # VMAF
            echo "    • Computing VMAF..."
            TMP_VMAF_FILE=$(mktemp)
            "$VMAF_TOOL_PATH" \
                --reference "$original_yuv_file" \
                --distorted "$decoded_yuv_file" \
                --width 2560 \
                --height 1440 \
                --bitdepth 8 \
                --pixel_format 420 \
                --model "$VMAF_MODEL_PATH" \
                --threads 12 \
                --output "$TMP_VMAF_FILE" \
                --csv \
                --frame_cnt 600 \
                --quiet

            if [ -f "$TMP_VMAF_FILE" ]; then
                VMAF_SCORES=$(tail -n +2 "$TMP_VMAF_FILE" | cut -d',' -f13)
                SUM_VMAF=0
                COUNT=0
                for SCORE in $VMAF_SCORES; do
                    SUM_VMAF=$(echo "$SUM_VMAF + $SCORE" | bc)
                    COUNT=$((COUNT + 1))
                done
                if [ "$COUNT" -gt 0 ]; then
                    VMAF_AVG=$(echo "scale=6; $SUM_VMAF / $COUNT" | bc)
                fi
                rm -f "$TMP_VMAF_FILE"
            fi

            # LPIPS
            echo "    • Computing LPIPS..."
            LPIPS_OUTPUT=$(python3 "$LPIPS_SCRIPT_PATH" --video1 "$original_yuv_file" --video2 "$decoded_yuv_file" --width 2560 --height 1440 --frames 300 2>/dev/null)
            LPIPS_VALUE=$(echo "$LPIPS_OUTPUT" | grep -oP 'Average LPIPS over 300 frames:\s+\K[0-9.]+')
        else
            echo "  ⚠ Skipping metrics: Missing decoded or original YUV file"
        fi

        echo "✅ Done: $row_name → Bitrate=$bitrate, PSNR=$PSNR_VALUE, SSIM=$SSIM_VALUE, VMAF=$VMAF_AVG, LPIPS=$LPIPS_VALUE"
        echo "${row_name},${bitrate},${PSNR_VALUE},${SSIM_VALUE},${VMAF_AVG},${LPIPS_VALUE}" >> "$output_file"
    done
done

echo "🎉 All processing completed. Results saved to $output_file"
