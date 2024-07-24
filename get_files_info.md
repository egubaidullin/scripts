# get_files_info Description

The provided script is a Python command-line utility that searches for files within a specified directory based on their creation date and logs the results. The user can specify a start date, end date, and path to search for files. The script also supports recursive search, exclusion of specific directories or files, and custom output formats (txt, csv, json).

## Usage Examples

1. Basic usage (uses current date as start date):
```bash
python get_files_info.py --path /home/user/documents
```
2. Specify start date:
```bash
python get_files_info.py --start-date 2023-07-24 --path /home/user/documents
```
3. Search with date range:
```bash
python get_files_info.py --start-date 2023-07-24 --end-date 2023-07-26 --path /home/user/documents
```
4. Recursive search with exclusions and custom output:
```bash
python get_files_info.py --path /home/user/projects --recursive --exclude .git node_modules --sort size --format json
```
Note: Dates should be in YYYY-MM-DD format. If start date is not provided, current date is used.

## --exclude Option

The `--exclude` option allows you to specify directories or files to be excluded from the search. You can provide multiple items to exclude by separating them with spaces. For example:
```bash
python get_files_info.py --path /home/user/projects --recursive --exclude .git node_modules
```
In this example, the script will exclude the `.git` and `node_modules` directories during the search.

## Output Formats

The script supports three output formats: txt, csv, and json. You can specify the desired output format using the `--format` option.

- `txt`: Plain text format. This is the default output format.
- `csv`: Comma-separated values format. Useful for importing the data into spreadsheet software.
- `json`: JavaScript Object Notation format. Ideal for machine-readable data and integration with other tools.

Example usage with different output formats:
```bash
# Text format (default)
python get_files_info.py --path /home/user/documents --format txt

# CSV format
python get_files_info.py --path /home/user/documents --format csv

# JSON format
python get_files_info.py --path /home/user/documents --format json
```
To use this script, save it as a `.py` file and execute it using Python 3. Make sure to provide the required arguments when running the script.
