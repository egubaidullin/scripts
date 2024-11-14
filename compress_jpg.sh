#!/bin/bash

# Default settings
THRESHOLD=409600    # 400KB
QUALITY=70          # JPEG quality
MAX_WIDTH=1920      # Maximum width
MAX_HEIGHT=1080     # Maximum height
LOG_FILE="compression_log.txt"

# Function to print usage
usage() {
    echo "Usage: $0 [-t threshold] [-q quality] [-w max_width] [-h max_height] directory"
    echo "Options:"
    echo "  -t: Threshold size in bytes (default: 409600)"
    echo "  -q: JPEG quality (0-100, default: 70)"
    echo "  -w: Maximum width (default: 1920)"
    echo "  -h: Maximum height (default: 1080)"
    exit 1
}

# Parse command line arguments
while getopts "t:q:w:h:" opt; do
    case $opt in
        t) THRESHOLD=$OPTARG ;;
        q) QUALITY=$OPTARG ;;
        w) MAX_WIDTH=$OPTARG ;;
        h) MAX_HEIGHT=$OPTARG ;;
        \?) usage ;;
    esac
done

# Shift to the directory argument
shift $((OPTIND-1))

# Check if directory argument is provided
if [[ -z "$1" ]]; then
    usage
fi

TARGET_DIR="$1"

# Check for required commands
for cmd in identify convert jpegoptim; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: $cmd is not installed"
        exit 1
    fi
done

# Initialize statistics
total_saved=0
processed_files=0
start_time=$(date +%s)

# Start logging
echo "Compression started at $(date)" > "$LOG_FILE"

# Process images
while IFS= read -r -d $'\0' img; do
    filesize_before=$(stat -c%s "$img")

    if (( filesize_before > THRESHOLD )); then
        # Get image dimensions, with error handling for corrupt files
        if ! resolution=$(identify -format "%wx%h" "$img" 2>/dev/null); then
            echo "$(date) - Failed to get dimensions for $img (possibly corrupt)" >> "$LOG_FILE"
            continue
        fi

        width=$(echo "$resolution" | cut -d'x' -f1)
        height=$(echo "$resolution" | cut -d'x' -f2)

        # Resize if necessary
        if (( width > MAX_WIDTH || height > MAX_HEIGHT )); then
            if ! convert "$img" -resize "${MAX_WIDTH}x${MAX_HEIGHT}>" "$img" 2>/dev/null; then
                echo "$(date) - Failed to resize $img (possibly corrupt)" >> "$LOG_FILE"
                continue
            else
                echo "$(date) - $img was resized to fit within ${MAX_WIDTH}x${MAX_HEIGHT}" >> "$LOG_FILE"
            fi
        fi

        # Check if optimization is needed and optimize
        if ! jpegoptim --no-action --max=$QUALITY "$img" > /dev/null 2>&1; then
            echo "$(date) - Failed to optimize $img (possibly corrupt)" >> "$LOG_FILE"
            continue
        fi

        # If optimization is possible, save space
        if jpegoptim --max=$QUALITY --strip-all "$img"; then
            filesize_after=$(stat -c%s "$img")
            saved=$((filesize_before - filesize_after))
            total_saved=$((total_saved + saved))
            processed_files=$((processed_files + 1))
            echo "$(date) - $img was optimized. Saved: $saved bytes" >> "$LOG_FILE"
        else
            echo "$(date) - Failed to optimize $img" >> "$LOG_FILE"
        fi
    fi
done < <(find "$TARGET_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" \) -print0)

# Calculate execution time
end_time=$(date +%s)
duration=$((end_time - start_time))

# Log final statistics
{
    echo "$(date) - Compression completed."
    echo "Total files processed: $processed_files"
    echo "Total space saved: $total_saved bytes"
    echo "Execution time: $duration seconds"
} >> "$LOG_FILE"

# Print summary to console
echo "Compression completed:"
echo "- Files processed: $processed_files"
echo "- Space saved: $total_saved bytes"
echo "- Time taken: $duration seconds"
echo "- See $LOG_FILE for details"
