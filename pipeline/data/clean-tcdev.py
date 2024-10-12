import argparse
import gzip
import random
import os
import re

# Define sentence-ending punctuation
SENTENCE_ENDINGS = re.compile(r'[.!?]')

def is_valid_line(source_line, target_line, seen_lines):
    """Check if the source line is valid based on conditions:
    - Source line must be longer than 5 words.
    - Source line must not have occurred before.
    - Source and target lines must have at most one sentence-ending punctuation.
    """
    # Check if the source line is longer than 5 words
    if len(source_line.split()) <= 5:
        return False

    # Check if the source line has occurred before
    if source_line in seen_lines:
        return False

    # Check if there is more than one sentence-ending punctuation in both lines
    if len(SENTENCE_ENDINGS.findall(source_line)) > 1 and len(SENTENCE_ENDINGS.findall(target_line)) > 1:
        return False

    # Add the source line to the set of seen lines
    seen_lines.add(source_line)
    return True

def process_files(source_path, target_path, prefix):
    """Process the gzipped source and target files, shuffle them, filter, sort by length, and write results to gzipped files."""
    seen_lines = set()

    # Read source and target files into memory, aligned by line
    with gzip.open(source_path, 'rt', encoding='utf-8') as src_file, \
         gzip.open(target_path, 'rt', encoding='utf-8') as tgt_file:
        lines = [(src_line.strip(), tgt_line.strip()) for src_line, tgt_line in zip(src_file, tgt_file)]

    # Shuffle the lines
    random.shuffle(lines)

    # Filter the lines based on conditions and store valid ones
    filtered_lines = [
        (src_line, tgt_line) for src_line, tgt_line in lines 
        if is_valid_line(src_line, tgt_line, seen_lines)
    ]

    # Sort the filtered lines by the length of the source line (longest first)
    sorted_lines = sorted(filtered_lines, key=lambda x: len(x[0]), reverse=True)

    # Generate output file paths by prefixing the file names
    source_output_path = prefix + os.path.basename(source_path)
    target_output_path = prefix + os.path.basename(target_path)

    # Write filtered and sorted lines to output files
    with gzip.open(source_output_path, 'wt', encoding='utf-8') as src_out_file, \
         gzip.open(target_output_path, 'wt', encoding='utf-8') as tgt_out_file:
        
        for src_line, tgt_line in sorted_lines:
            src_out_file.write(src_line + '\n')
            tgt_out_file.write(tgt_line + '\n')

def main():
    # Argument parsing
    parser = argparse.ArgumentParser(description='Process gzipped files, shuffle lines, filter, sort, and output them.')
    parser.add_argument('--source', required=True, help='Path to the gzipped source file')
    parser.add_argument('--target', required=True, help='Path to the gzipped target file')
    parser.add_argument('--prefix', required=True, help='Prefix to be added to output file names')

    args = parser.parse_args()

    # Process the input files and generate output
    process_files(args.source, args.target, args.prefix)

if __name__ == "__main__":
    main()

