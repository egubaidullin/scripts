#!/bin/bash

# Default settings
THRESHOLD=409600    # 400KB - file size threshold for compression
MAX_WIDTH=1920      # Maximum image width
MAX_HEIGHT=1080     # Maximum image height
MAX_COLORS=256      # Maximum colors for PNG palette
MIN_QUALITY=65      # Minimum PNG compression quality
MAX_QUALITY=80      # Maximum PNG compression quality  
LOG_FILE="png_compression_log.txt"

# Function to print usage instructions
usage() {
    echo "Usage: $0 [-t threshold] [-w max_width] [-h max_height] [-c max_colors] [-n min_quality] [-x max_quality] directory"
    echo "Options:"
    echo "  -t: Threshold size in bytes (default: 409600)"
    echo "  -w: Maximum width (default: 1920)" 
    echo "  -h: Maximum height (default: 1080)"
    echo "  -c: Maximum colors (default: 256)"
    echo "  -n: Minimum quality (default: 65)"
    echo "  -x: Maximum quality (default: 80)"
    exit 1
}

# Parse command line arguments
while getopts "t:w:h:c:n:x:" opt; do
    case $opt in
        t) THRESHOLD=$OPTARG ;;
        w) MAX_WIDTH=$OPTARG ;;
        h) MAX_HEIGHT=$OPTARG ;;
        c) MAX_COLORS=$OPTARG ;;
        n) MIN_QUALITY=$OPTARG ;;
        x) MAX_QUALITY=$OPTARG ;;
        \?) usage ;;
    esac
done

# Validate quality values
if (( MIN_QUALITY < 0 || MIN_QUALITY > 100 || MAX_QUALITY < 0 || MAX_QUALITY > 100 || MIN_QUALITY > MAX_QUALITY )); then
    echo "Error: Invalid quality values. Must be between 0-100 and min_quality must be less than or equal to max_quality"
    exit 1
fi

# Construct quality range for pngquant
QUALITY_RANGE="${MIN_QUALITY}-${MAX_QUALITY}"

# Shift to the directory argument
shift $((OPTIND-1))

# Check if directory argument is provided
if [[ -z "$1" ]]; then
    usage
fi

TARGET_DIR="$1"

# Verify directory exists and is accessible
if [[ ! -d "$TARGET_DIR" ]]; then
    echo "Error: Directory $TARGET_DIR does not exist"
    exit 1
fi

if [[ ! -r "$TARGET_DIR" || ! -w "$TARGET_DIR" ]]; then
    echo "Error: Insufficient permissions for directory $TARGET_DIR"
    exit 1
fi

# Check for required utilities
for cmd in identify convert pngquant optipng; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: $cmd is not installed"
        exit 1
    fi
done

# Check available disk space
available_space=$(df -B1 "$TARGET_DIR" | awk 'NR==2 {print $4}')
if (( available_space < THRESHOLD )); then
    echo "Error: Insufficient disk space"
    exit 1
fi

# Initialize statistics counters
total_saved=0
processed_files=0
skipped_files=0
start_time=$(date +%s)

# Initialize log file
echo "Compression started at $(date)" > "$LOG_FILE"

# Process PNG images
while IFS= read -r -d $'\0' img; do
    filesize_before=$(stat -c%s "$img")

    if (( filesize_before > THRESHOLD )); then
        # Get image dimensions
        if ! resolution=$(identify -format "%wx%h" "$img" 2>/dev/null); then
            echo "$(date) - Failed to get dimensions for $img" >> "$LOG_FILE"
            continue
        fi

        # Get color count
        if ! color_count=$(identify -format "%k" "$img" 2>/dev/null); then
            echo "$(date) - Failed to get color count for $img" >> "$LOG_FILE"
            continue
        fi

        width=$(echo "$resolution" | cut -d'x' -f1)
        height=$(echo "$resolution" | cut -d'x' -f2)

        # Skip if color count is already within limits
        if (( color_count <= MAX_COLORS )); then
            echo "$(date) - $img already has $color_count colors, skipping." >> "$LOG_FILE"
            skipped_files=$((skipped_files + 1))
            continue
        fi

        # Resize image if it exceeds maximum dimensions
        if (( width > MAX_WIDTH || height > MAX_HEIGHT )); then
            if convert "$img" -resize "${MAX_WIDTH}x${MAX_HEIGHT}>" "$img"; then
                echo "$(date) - $img was resized to fit within ${MAX_WIDTH}x${MAX_HEIGHT}" >> "$LOG_FILE"
            else
                echo "$(date) - Failed to resize $img" >> "$LOG_FILE"
                continue
            fi
        fi

        # Compress using pngquant
        if pngquant --quality=$QUALITY_RANGE --ext .png --force "$img"; then
            echo "$(date) - $img was compressed with pngquant (quality range: $QUALITY_RANGE)" >> "$LOG_FILE"
        else
            echo "$(date) - Failed to compress $img with pngquant" >> "$LOG_FILE"
            continue
        fi

        # Further optimize using optipng
        if optipng -o7 "$img"; then
            filesize_after=$(stat -c%s "$img")
            saved=$((filesize_before - filesize_after))
            total_saved=$((total_saved + saved))
            processed_files=$((processed_files + 1))
            echo "$(date) - $img was optimized with optipng. Saved: $saved bytes" >> "$LOG_FILE"
        else
            echo "$(date) - Failed to optimize $img with optipng" >> "$LOG_FILE"
        fi
    fi
done < <(find "$TARGET_DIR" -type f -iname "*.png" -print0)

# Calculate total execution time
end_time=$(date +%s)
duration=$((end_time - start_time))

# Log final statistics
{
    echo "$(date) - Compression completed."
    echo "Total files processed: $processed_files"
    echo "Files skipped: $skipped_files"
    echo "Total space saved: $total_saved bytes"
    echo "Execution time: $duration seconds"
} >> "$LOG_FILE"

# Print summary to console
echo "Compression completed:"
echo "- Files processed: $processed_files"
echo "- Files skipped: $skipped_files"
echo "- Space saved: $total_saved bytes"
echo "- Time taken: $duration seconds"
echo "- See $LOG_FILE for details"
