import argparse
import os
import sys
import mimetypes
import concurrent.futures
import logging
from tqdm import tqdm

# Configuration variables
SKIP_DIRS = {'.idea', '.venv', '__pycache__', 'node_modules'}
TEXT_EXTENSIONS = {'.txt', '.py', '.js', '.html', '.css', '.md', '.json', '.xml', '.csv', '.ini', '.cfg', '.yaml', '.yml'}
MAX_FILE_SIZE = 10 * 1024 * 1024  # 10 MB
MAX_WORKERS = 4

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def is_text_file(file_path):
    if not os.path.splitext(file_path)[1]:
        try:
            with open(file_path, 'rb') as f:
                return not bool(f.read(1024).translate(None, bytes([7,8,9,10,12,13,27] + list(range(0x20, 0x100))))) 
        except IOError:
            return False
    
    mime_type, _ = mimetypes.guess_type(file_path)
    return mime_type and mime_type.startswith('text') or os.path.splitext(file_path)[1].lower() in TEXT_EXTENSIONS

def write_file_content(out_file, file_path, rel_path):
    out_file.write(f"<file path=\"{rel_path}\">\n")
    out_file.write("<content>\n")
    
    try:
        if os.path.getsize(file_path) > MAX_FILE_SIZE:
            out_file.write(f"File size exceeds limit of {MAX_FILE_SIZE} bytes\n")
        elif not is_text_file(file_path):
            out_file.write("Non-text file, content not included\n")
        else:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as in_file:
                content = in_file.read()
            out_file.write(content)
    except IOError as e:
        logging.warning(f"Could not read file '{rel_path}': {e}")
        out_file.write(f"Error: {str(e)}\n")
    
    out_file.write("</content>\n")
    out_file.write("</file>\n\n")

def write_directory_structure(out_file, input_dir):
    def print_tree(dir_path, prefix=""):
        entries = os.listdir(dir_path)
        entries = [e for e in entries if e not in SKIP_DIRS]
        entries = sorted(entries, key=lambda x: (os.path.isfile(os.path.join(dir_path, x)), x))
        
        for i, entry in enumerate(entries):
            full_path = os.path.join(dir_path, entry)
            is_last = i == len(entries) - 1
            out_file.write(f"{prefix}{'└── ' if is_last else '├── '}{entry}\n")
            
            if os.path.isdir(full_path) and entry not in SKIP_DIRS:
                extension = "    " if is_last else "│   "
                print_tree(full_path, prefix + extension)

    out_file.write(f"{os.path.basename(input_dir)}/\n")
    print_tree(input_dir)

def process_file(args):
    root_dir, file, input_dir, out_file = args
    file_path = os.path.join(root_dir, file)
    rel_path = os.path.relpath(file_path, input_dir)
    write_file_content(out_file, file_path, rel_path)

def main():
    parser = argparse.ArgumentParser(description=f"Generate a text file containing contents and structure of files in a directory and its subdirectories, skipping {', '.join(SKIP_DIRS)} directories.")
    parser.add_argument("input_dir", help="Input directory path")
    parser.add_argument("-s", action="store_true", help="Save directory structure to a file")
    parser.add_argument("-f", action="store_true", help="Save file contents to a file")
    args = parser.parse_args()

    input_dir = args.input_dir
    if not os.path.isdir(input_dir):
        logging.error(f"'{input_dir}' is not a valid directory.")
        sys.exit(1)

    if not args.s and not args.f:
        parser.print_help()
        sys.exit(1)

    if args.s:
        output_file_structure = os.path.join(os.getcwd(), f"{os.path.basename(input_dir)}_structure.txt")
        try:
            with open(output_file_structure, 'w', encoding='utf-8') as out_file:
                write_directory_structure(out_file, input_dir)
            logging.info(f"Structure output file created successfully: {output_file_structure}")
        except IOError as e:
            logging.error(f"Could not create or write to structure output file: {e}")
            sys.exit(1)

    if args.f:
        output_file_contents = os.path.join(os.getcwd(), f"{os.path.basename(input_dir)}_contents.txt")
        try:
            with open(output_file_contents, 'w', encoding='utf-8') as out_file:
                file_list = []
                for root_dir, dirs, files in os.walk(input_dir):
                    dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
                    file_list.extend((root_dir, file, input_dir, out_file) for file in files)
                
                with concurrent.futures.ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
                    list(tqdm(executor.map(process_file, file_list), total=len(file_list), desc="Processing files"))
            
            logging.info(f"Contents output file created successfully: {output_file_contents}")
        except IOError as e:
            logging.error(f"Could not create or write to contents output file: {e}")
            sys.exit(1)

if __name__ == "__main__":
    main()
