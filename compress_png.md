# PNG Compression Script

This script compresses PNG images in a specified directory and its subdirectories if their file size exceeds a certain threshold. It uses `pngquant` and `optipng` to compress the images and remove metadata. Additionally, it resizes images if their resolution exceeds a specified maximum resolution while preserving the aspect ratio.

## Prerequisites

Before running the script, ensure you have the following tools installed:

- `pngquant`
- `optipng`
- `ImageMagick` (for `identify` and `convert` commands)

You can install them using your package manager. For example, on Ubuntu:

```bash
sudo apt-get install pngquant optipng imagemagick
```

##  Usage

./compress_png.sh [-t threshold] [-w max_width] [-h max_height] [-c max_colors] [-n min_quality] [-x max_quality] directory
Replace directory with the path of the directory containing the PNG images you want to compress.

###  Options
-t threshold: Threshold size in bytes (default: 409600)
-w max_width: Maximum width (default: 1920)
-h max_height: Maximum height (default: 1080)
-c max_colors: Maximum colors for PNG palette (default: 256)
-n min_quality: Minimum PNG compression quality (default: 65)
-x max_quality: Maximum PNG compression quality (default: 80)
