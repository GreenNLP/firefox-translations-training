import yaml
import argparse

def convert_txt_to_yaml(input_file, output_file):
    # Initialize an empty dictionary
    data = {}

    # Open and read the input file
    with open(input_file, 'r', encoding='utf-8') as infile:
        # Loop through each line in the file
        for idx, line in enumerate(infile):
            # Split the line by whitespace and take the first column
            first_column = line.split()[0]
            # Add the first column as a key, and idx as the value
            data[first_column] = idx

    # Write the dictionary to a YAML file
    with open(output_file, 'w', encoding='utf-8') as outfile:
        yaml.dump(data, outfile, default_flow_style=False, allow_unicode=True)

def main():
    # Set up the argument parser
    parser = argparse.ArgumentParser(description='Convert a whitespace-delimited text file to a YAML file.')
    parser.add_argument('input_vocab', help='Path to the txt format .vocab file produced by sentencepiece')
    parser.add_argument('output_vocab', help='Path to the output YAML file')

    # Parse the arguments
    args = parser.parse_args()

    # Call the conversion function with the provided input and output file paths
    convert_txt_to_yaml(args.input_file, args.output_file)

if __name__ == '__main__':
    main()

