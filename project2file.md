# Project2File

Project2File is a Python script for saving project structure and file contents to text files.

## Description

Project2File allows you to capture your project's structure and file contents in separate text files. It generates two types of outputs:

1. A text file containing the directory structure as a tree using pseudo-graphics.
2. A text file containing the contents of text files in the project.

## Key Features

- Save project directory structure to a file
- Save contents of text files to a file
- Skip specified directories
- Process text files based on content, not just extension
- Multi-threaded processing for improved performance

## Usage
```
python project2file.py [-h] [-s] [-f] input_dir
```

Arguments:
- `input_dir`: Path to the directory to analyze
- `-s`: Save directory structure to a file
- `-f`: Save file contents to a file
- `-h`: Show help message

## Configurable Variables

The following variables can be modified at the beginning of the script:

- `SKIP_DIRS`: Set of directories to skip during processing.
- `TEXT_EXTENSIONS`: File extensions considered as text files. Use `{'*'}` to check all files.
- `MAX_FILE_SIZE`: Maximum size of a file to process (in bytes).
- `MAX_WORKERS`: Number of threads for file processing.

To add new extensions, simply add them to the `TEXT_EXTENSIONS` set. For example:
```
TEXT_EXTENSIONS = {'.txt', '.py', '.js', '.html', '.css', '.md', '.json', '.xml', '.csv', '.ini', '.cfg', '.yaml', '.yml', '.new_extension'}
```

## Dependencies

- Python 3.6+
- tqdm

## Note

The script uses UTF-8 encoding when reading files. Files with other encodings may not display correctly.
