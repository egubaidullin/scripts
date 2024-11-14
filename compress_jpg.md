# Compress JPEG Lossy

This script compresses JPEG images in a specified directory and its subdirectories if their file size exceeds a certain threshold. It uses `jpegoptim` to compress the images to a specified quality and remove metadata.

## Prerequisites

Before running the script, ensure you have the following tool installed:

- `jpegoptim`

You can install it using your package manager. For example, on Ubuntu:

```bash
sudo apt-get install jpegoptim
```

## Usage

```
./compress_jpg.sh <directory>
```

Replace <directory> with the path of the directory containing the JPEG images you want to compress.
