#!/bin/bash

# List of games
games=("COD" "DEVIL" "FORZA" "PES")

# List of base folders (key: folder name, value: path)
declare -A base_folders
base_folders=(
    ["nonROI"]="/home/resist/MG/PacketWash/h264_over_bpp-main/ICINT/nonROI"
    ["ROI"]="/home/resist/MG/PacketWash/h264_over_bpp-main/ICINT/ROI/gblur"
    ["ManualROI"]="/home/resist/MG/PacketWash/h264_over_bpp-main/ICINT/ManualROI/gblur"
)

# Output CSV file
output_csv="merged_file_size_report.csv"

# Write CSV header
echo "Folder,Game,Threshold,Encoded File Size (bytes),BPP File Size (bytes),Reduction (%)" > "$output_csv"

# Function to process a base folder
process_folder() {
    local folder_name=$1
    local base_path=$2

    echo "Processing folder: $folder_name"

    for i in "${!games[@]}"; do
        game=${games[$i]}
        echo "[$((i+1))/${#games[@]}] Processing $game in $folder_name..."

        # Use arrays with wildcards to handle flexible filenames
        encoded_file=($base_path/$game/Encoded/*${game}*.264)
        th5_file=($base_path/$game/BPP/*_Th5*.264)
        th10_file=($base_path/$game/BPP/*_Th10*.264)

        # Get Encoded file size
        encoded_size="NA"
        [[ -f "${encoded_file[0]}" ]] && encoded_size=$(stat -c%s "${encoded_file[0]}")

        # --- Process Th10 first ---
        th10_size="NA"
        reduction_th10="NA"
        if [[ -f "${th10_file[0]}" ]]; then
            th10_size=$(stat -c%s "${th10_file[0]}")
            [[ "$encoded_size" != "NA" ]] && reduction_th10=$(awk "BEGIN {printf \"%.2f\", (($encoded_size - $th10_size)/$encoded_size)*100}")
        fi
        echo "$folder_name,$game,Th10,$encoded_size,$th10_size,$reduction_th10" >> "$output_csv"

        # --- Process Th5 second ---
        th5_size="NA"
        reduction_th5="NA"
        if [[ -f "${th5_file[0]}" ]]; then
            th5_size=$(stat -c%s "${th5_file[0]}")
            [[ "$encoded_size" != "NA" ]] && reduction_th5=$(awk "BEGIN {printf \"%.2f\", (($encoded_size - $th5_size)/$encoded_size)*100}")
        fi
        echo "$folder_name,$game,Th5,$encoded_size,$th5_size,$reduction_th5" >> "$output_csv"

    done
}

# Loop over all base folders
for folder_name in "${!base_folders[@]}"; do
    process_folder "$folder_name" "${base_folders[$folder_name]}"
done

echo "All processing complete! Merged results saved to $output_csv"
