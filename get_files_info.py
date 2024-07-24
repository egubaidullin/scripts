#!/usr/bin/env python3
import os
import argparse
from datetime import datetime, timedelta
import sys
import csv
import json
import locale

def get_system_encoding():
    return locale.getpreferredencoding()

def parse_arguments():
    parser = argparse.ArgumentParser(
        description="Search for files by creation date and log them.",
        epilog="""
Examples:
  1. Basic usage (uses current date as start date):
     %(prog)s --path /home/user/documents

  2. Specify start date:
     %(prog)s --start-date 2023-07-24 --path /home/user/documents

  3. Search with date range:
     %(prog)s --start-date 2023-07-24 --end-date 2023-07-26 --path /home/user/documents

  4. Recursive search with exclusions and custom output:
     %(prog)s --path /home/user/projects --recursive --exclude .git node_modules --sort size --format json

Note: Dates should be in YYYY-MM-DD format. If start date is not provided, current date is used.
""",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    parser.add_argument("--start-date", help="Start date to filter files (YYYY-MM-DD). If not provided, current date is used.")
    parser.add_argument("--end-date", help="End date to filter files (YYYY-MM-DD). If not provided, only start date is used.")
    parser.add_argument("--path", required=True, help="Path to search for files")
    parser.add_argument("--recursive", action="store_true", help="Search recursively in subdirectories")
    parser.add_argument("--exclude", nargs='+', help="Directories or files to exclude (e.g., .git node_modules)")
    parser.add_argument("--sort", choices=['name', 'size', 'date'], default='name', 
                        help="Sort files by name, size, or date (default: name)")
    parser.add_argument("--format", choices=['txt', 'csv', 'json'], default='txt', 
                        help="Output format (default: txt)")
    
    return parser.parse_args()

def get_file_info(file_path):
    try:
        stat = os.stat(file_path)
        return {
            'name': os.path.basename(file_path),
            'path': file_path,
            'size': stat.st_size,
            'date': datetime.fromtimestamp(stat.st_mtime)
        }
    except Exception as e:
        print(f"Error getting info for {file_path}: {e}", file=sys.stderr)
        return None

def should_exclude(path, exclude_list):
    return any(exclude in path for exclude in (exclude_list or []))

def scan_directory(root_path, start_date, end_date, recursive, exclude_list):
    file_structure = []
    total_files = 0
    matching_files = 0
    system_encoding = get_system_encoding()

    for root, dirs, files in os.walk(root_path):
        if not recursive and root != root_path:
            break

        if should_exclude(root, exclude_list):
            continue

        for file in files:
            total_files += 1
            try:
                file_path = os.path.join(root, file)
                file_stat = os.stat(file_path)
                file_date = datetime.fromtimestamp(file_stat.st_mtime).date()
                if start_date <= file_date <= end_date:
                    matching_files += 1
                    file_structure.append({
                        'name': file.encode(system_encoding, errors='replace').decode(system_encoding),
                        'path': file_path.encode(system_encoding, errors='replace').decode(system_encoding),
                        'date': datetime.fromtimestamp(file_stat.st_mtime),
                        'size': file_stat.st_size
                    })
            except (OSError, ValueError, UnicodeEncodeError, UnicodeDecodeError) as e:
                print(f"Error processing file: {file}: {e}", file=sys.stderr)

    return file_structure, total_files, matching_files

def sort_files(file_structure, sort_key):
    if sort_key == 'name':
        return sorted(file_structure, key=lambda x: x['name'])
    elif sort_key == 'size':
        return sorted(file_structure, key=lambda x: x['size'], reverse=True)
    elif sort_key == 'date':
        return sorted(file_structure, key=lambda x: x['date'])

def write_txt_log(file_structure, start_date, end_date, output_file):
    with open(output_file, 'w', encoding='utf-8', errors='replace') as f:
        if start_date <= end_date:
            f.write(f"<{start_date} to {end_date}>\n")
        else:
            f.write(f"<Files created on or before {end_date}>\n")
        current_folder = None
        for file in file_structure:
            folder = os.path.dirname(file['path'])
            if folder != current_folder:
                if current_folder:
                    f.write(f"</{current_folder}>\n")
                f.write(f"<{folder}>\n")
                current_folder = folder
            f.write(f"{file['name']} ({file['date'].strftime('%Y-%m-%d %H:%M:%S')}, {file['size']} bytes)\n")
        if current_folder:
            f.write(f"</{current_folder}>\n")
        if start_date <= end_date:
            f.write(f"</{start_date} to {end_date}>\n")
        else:
            f.write(f"</Files created on or before {end_date}>\n")

def write_csv_log(file_structure, start_date, end_date, output_file):
    with open(output_file, 'w', newline='', encoding='utf-8', errors='replace') as f:
        writer = csv.writer(f)
        if start_date <= end_date:
            writer.writerow(['Date Range', f"{start_date} to {end_date}"])
        else:
            writer.writerow(['Date Range', f"Files created on or before {end_date}"])
        writer.writerow([])  # ?????? ?????? ??? ??????????
        writer.writerow(['Name', 'Path', 'Date', 'Size (bytes)'])
        for file in file_structure:
            writer.writerow([file['name'], file['path'], file['date'].strftime('%Y-%m-%d %H:%M:%S'), file['size']])

def write_json_log(file_structure, start_date, end_date, output_file):
    if start_date <= end_date:
        date_range = f"{start_date} to {end_date}"
    else:
        date_range = f"Files created on or before {end_date}"
    
    data = {
        'date_range': date_range,
        'files': [
            {
                'name': file['name'],
                'path': file['path'],
                'date': file['date'].strftime('%Y-%m-%d %H:%M:%S'),
                'size': file['size']
            } for file in file_structure
        ]
    }
    with open(output_file, 'w', encoding='utf-8', errors='replace') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

def main():
    if len(sys.argv) == 1:
        print("Usage: file_logger.py --path /path/to/search [options]")
        print("For more information and examples, use the -h or --help option.")
        sys.exit(1)

    args = parse_arguments()
    
    start_date = datetime.strptime(args.start_date, "%Y-%m-%d").date() if args.start_date else datetime.now().date()
    end_date = datetime.strptime(args.end_date, "%Y-%m-%d").date() if args.end_date else start_date
    root_path = args.path

    if not os.path.exists(root_path):
        print(f"Error: The specified path '{root_path}' does not exist.", file=sys.stderr)
        sys.exit(1)

    print(f"Scanning directory: {root_path}")
    print(f"Date range: {start_date} to {end_date}")

    if start_date > end_date:
        print("Warning: Start date is later than end date. Searching for files created on or before the end date.")

    try:
        file_structure, total_files, matching_files = scan_directory(root_path, start_date, end_date, args.recursive, args.exclude)
        file_structure = sort_files(file_structure, args.sort)

        output_file = f"files_log.{args.format}"
        if args.format == 'txt':
            write_txt_log(file_structure, start_date, end_date, output_file)
        elif args.format == 'csv':
            write_csv_log(file_structure, start_date, end_date, output_file)
        elif args.format == 'json':
            write_json_log(file_structure, start_date, end_date, output_file)

        print(f"\nScan complete.")
        print(f"Total files scanned: {total_files}")
        print(f"Files matching the date range: {matching_files}")
        print(f"Log file created: {output_file}")
    except Exception as e:
        print(f"An error occurred: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
