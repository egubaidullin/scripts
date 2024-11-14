#!/bin/bash

# Set the threshold size in bytes (e.g., 400 KB = 409600 bytes)
THRESHOLD=409600

# Log file path
LOG_FILE="compression_log.txt"

# Quality threshold (percentage)
QUALITY=80

# Check if directory argument is provided
if [[ -z "$1" ]]; then
    echo "Usage: $0 <directory>"
    exit 1
fi

# Target directory
TARGET_DIR="$1"

# Start logging
echo "Compression started at $(date)" > "$LOG_FILE"

# Find and process each JPEG file in the specified directory and its subdirectories
find "$TARGET_DIR" -type f -iname "*.jpg" -o -iname "*.jpeg" | while read -r img; do
    # Get the file size before compression
    filesize_before=$(stat -c%s "$img")

    # Check if file size exceeds the threshold
    if (( filesize_before > THRESHOLD )); then
        # Check if the file can still be optimized
        jpegoptim --no-action --max=$QUALITY "$img" > /dev/null 2>&1

        # If the output indicates the file can be optimized, proceed with compression
        if [[ $? -eq 0 ]]; then
            # Compress the JPEG image to the specified quality and remove metadata
            jpegoptim --max=$QUALITY --strip-all "$img"
            echo "$(date) - $img was compressed to $QUALITY% quality and metadata removed." >> "$LOG_FILE"
        else
            echo "$(date) - $img is already optimized, skipping." >> "$LOG_FILE"
        fi
    fi
done

# Completion message
echo "$(date) - Compression completed." >> "$LOG_FILE"
echo "Compression completed."
