import yaml
import argparse

def merge_decoders(decoder_file_1, decoder_file_2, output_decoder_file, vocab_file, decoder_1_weight):
    # Load the YAML files
    with open(decoder_file_1, 'r') as f1, open(decoder_file_2, 'r') as f2:
        decoder_1 = yaml.safe_load(f1)
        decoder_2 = yaml.safe_load(f2)

    # Retain all keys from decoder 1 except 'models'
    output_data = {key: value for key, value in decoder_1.items() if key != 'models'}

    # Merge the models from both decoders
    merged_models = decoder_1['models'] + decoder_2['models']
    output_data['models'] = merged_models

    # Add the weights for decoder 1 and decoder 2
    output_data['weights'] = [decoder_1_weight, 1 - decoder_1_weight]

    # Save the merged data to the output YAML file
    with open(output_decoder_file, 'w') as outfile:
        yaml.safe_dump(output_data, outfile)

def main():
    # Argument parser setup
    parser = argparse.ArgumentParser(description="Merge two decoder YAML files")
    parser.add_argument('--decoder_file_1', type=str, help="Path to the first decoder YAML file")
    parser.add_argument('--decoder_file_2', type=str, help="Path to the second decoder YAML file")
    parser.add_argument('--output_decoder_file', type=str, help="Path to the output decoder YAML file")
    parser.add_argument('--vocab_file', type=str, help="Path to the vocabulary file")
    parser.add_argument('--decoder_1_weight', type=float, help="Weight for the first decoder (0 <= weight <= 1)")

    args = parser.parse_args()

    # Ensure the decoder 1 weight is between 0 and 1
    if not (0 <= args.decoder_1_weight <= 1):
        raise ValueError("The weight for the first decoder must be between 0 and 1.")

    # Merge the decoders
    merge_decoders(args.decoder_file_1, args.decoder_file_2, args.output_decoder_file, args.vocab_file, args.decoder_1_weight)

if __name__ == '__main__':
    main()

