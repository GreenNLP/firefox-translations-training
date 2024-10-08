import argparse

def replace_fuzzy_lines(non_fuzzy_file, fuzzy_file, fuzzy_line_number_file, output_path):
    # Read lines from the non-fuzzy translation file
    with open(non_fuzzy_file, 'r', encoding='utf-8') as nf:
        non_fuzzy_lines = nf.readlines()

    # Read lines from the fuzzy translation file
    with open(fuzzy_file, 'r', encoding='utf-8') as f:
        fuzzy_lines = f.readlines()

    # Read the fuzzy line numbers (1-based index)
    with open(fuzzy_line_number_file, 'r', encoding='utf-8') as fln:
        fuzzy_line_numbers = [int(line.strip().split(":")[0]) for line in fln.readlines()]

    # Replace lines in non-fuzzy lines with those from fuzzy lines based on fuzzy line numbers
    for (line_number_index, line_number) in enumerate(fuzzy_line_numbers):
        print(line_number)
        # Check if the line number is within range
        if 1 <= line_number <= len(non_fuzzy_lines):
            non_fuzzy_lines[line_number - 1] = fuzzy_lines[line_number_index]

    # Write the modified lines to the output file
    with open(output_path, 'w', encoding='utf-8') as output_file:
        output_file.writelines(non_fuzzy_lines)

def main():
    # Set up argument parsing
    parser = argparse.ArgumentParser(description='Replace lines in a non-fuzzy translation file with lines from a fuzzy translation file based on provided line numbers.')
    parser.add_argument('non_fuzzy_file', type=str, help='Path to the non-fuzzy translation file.')
    parser.add_argument('fuzzy_file', type=str, help='Path to the fuzzy translation file.')
    parser.add_argument('fuzzy_line_number_file', type=str, help='Path to the file containing fuzzy line numbers.')
    parser.add_argument('output_path', type=str, help='Path to the output file where modified content will be saved.')

    # Parse the arguments
    args = parser.parse_args()

    # Call the function to replace fuzzy lines
    replace_fuzzy_lines(args.non_fuzzy_file, args.fuzzy_file, args.fuzzy_line_number_file, args.output_path)

if __name__ == '__main__':
    main()

