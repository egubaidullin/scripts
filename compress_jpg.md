# JPEG Compression Script

This script compresses JPEG images in a specified directory and its subdirectories if their file size exceeds a certain threshold. It uses `jpegoptim` to compress the images to a specified quality and remove metadata. Additionally, it resizes images if their resolution exceeds a specified maximum resolution while preserving the aspect ratio.

## Prerequisites

Before running the script, ensure you have the following tools installed:

- `jpegoptim`
- `ImageMagick` (for `identify` and `convert` commands)

You can install them using your package manager. For example, on Ubuntu:

```bash
sudo apt-get install jpegoptim imagemagick
```

##  Usage

```
./compress_jpg.sh [-t threshold] [-q quality] [-w max_width] [-h max_height] directory
```

Replace directory with the path of the directory containing the JPEG images you want to compress.

##  Options
-t threshold: Threshold size in bytes (default: 409600)
-q quality: JPEG quality (0-100, default: 70)
-w max_width: Maximum width (default: 1920)
-h max_height: Maximum height (default: 1080)
