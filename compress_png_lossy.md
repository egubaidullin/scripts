# Compress PNG Lossy

This script compresses PNG images in a specified directory and its subdirectories if their file size exceeds a certain threshold. It uses `pngquant` to reduce the number of colors to a specified maximum and `optipng` for further optimization without loss.

## Prerequisites

Before running the script, ensure you have the following tools installed:

- `ImageMagick` (for `identify` command)
- `pngquant`
- `optipng`

You can install them using your package manager. For example, on Ubuntu:

```bash
sudo apt-get install imagemagick pngquant optipng
```
## Usage

```
./compress_png_lossy.sh <directory>
```

Replace <directory> with the path of the directory containing the PNG images you want to compress.


