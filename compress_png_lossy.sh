#!/bin/bash

# Set the threshold size in bytes (e.g., 400 KB = 409600 bytes)
THRESHOLD=409600

# Set the maximum number of colors
MAX_COLORS=256

# Log file path
LOG_FILE="png_compression_log.txt"

# Check if directory argument is provided
if [[ -z "$1" ]]; then
    echo "Usage: $0 <directory>"
    exit 1
fi

# Target directory
TARGET_DIR="$1"

# Start logging
echo "Compression started at $(date)" > "$LOG_FILE"

# Find and process each PNG file in the specified directory and its subdirectories
find "$TARGET_DIR" -type f -iname "*.png" | while read -r img; do
    # Get the file size
    filesize=$(stat -c%s "$img")

    # Check if file size exceeds the threshold
    if (( filesize > THRESHOLD )); then
        # Get the number of colors in the PNG file using ImageMagick's identify tool
        color_count=$(identify -format "%k" "$img")

        # If the number of colors is less than or equal to MAX_COLORS, skip the file
        if (( color_count <= MAX_COLORS )); then
            echo "$(date) - $img already has $color_count colors, skipping." >> "$LOG_FILE"
            continue
        fi

        # Compress the PNG by reducing the number of colors to MAX_COLORS using pngquant
        pngquant --quality=65-80 --ext .png --force "$img"
        echo "$(date) - $img was compressed with reduced colors to $MAX_COLORS." >> "$LOG_FILE"

        # Further optimize the PNG using optipng without loss
        optipng -o7 "$img"
        echo "$(date) - $img was optimized with optipng." >> "$LOG_FILE"
    fi
done

# Completion message
echo "$(date) - Compression completed." >> "$LOG_FILE"
echo "Compression completed."
