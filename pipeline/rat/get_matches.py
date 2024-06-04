import argparse
import gzip
import os

def read_sentence_file(filepath):
    ext = os.path.splitext(filepath)[-1].lower()
    if ext == ".gz":
        with gzip.open(filepath, 'rt') as file:
            return [line.strip() for line in file.readlines()]
    else:
        with open(filepath, 'rt') as file:
            return [line.strip() for line in file.readlines()]

def read_score_file(filepath):
    scores = {}
    with open(filepath, 'r') as file:
        index = 0
        for line in file:
            parts = [x for x in line.strip().split('\t') if x]
            if len(parts) > 0:
                scores[index] = sorted([(float(parts[i]), int(parts[i+1])) for i in range(0, len(parts), 2)], key=lambda x: x[1], reverse=True)
            index += 1
    return scores

def main(args):
    print("Reading sentences")
    src_sentences = read_sentence_file(args.src_sentence_file)
    trg_sentences = read_sentence_file(args.trg_sentence_file)
    scores = read_score_file(args.score_file)
    index_src_sentences = read_sentence_file(args.index_src_sentence_file)
    index_trg_sentences = read_sentence_file(args.index_trg_sentence_file)

    with gzip.open(args.src_augmented_file,'w') as output_file:
        print("Looking for fuzzies")
        for index, sentence in enumerate(src_sentences):
            if index in scores:
                score_indices = scores[index]
                corresponding_sentences = [index_trg_sentences[i-1] for score, i in score_indices if score > args.min_score][0:args.max_fuzzies]
                if len(corresponding_sentences) >= args.min_fuzzies:
                    output_file.write(f"{args.fuzzy_separator.join(corresponding_sentences)}{args.fuzzy_separator}{sentence}")

if __name__ == "__main__":
    # Set up argument parsing
    parser = argparse.ArgumentParser(description="Augment data with fuzzies from index.")
    parser.add_argument("--src_sentence_file", help="Path to the file containing the source sentences that should be augmented with fuzzies.")
    parser.add_argument("--trg_sentence_file", help="Path to the file containing the target sentences that should be augmented with fuzzies.")
    parser.add_argument("--score_file", help="Path to the file containing the indices of fuzzies found for each sentence in the sentence file")
    parser.add_argument("--src_augmented_file", help="Path to save the source file augmented with fuzzies.")
    parser.add_argument("--trg_augmented_file", help="Path to save the target file augmented with fuzzies.")
    parser.add_argument("--index_src_sentence_file", help="Path to the file containing the source sentences corresponding to the fuzzy indices in the score file")
    parser.add_argument("--index_trg_sentence_file", help="Path to the file containing the target sentences corresponding to the fuzzy indices in the score file")
    parser.add_argument("--fuzzy_separator", help="Separator token that separates the fuzzies from other fuzzies and the source sentence")
    parser.add_argument("--min_score", type=float, help="Only consider fuzzies that have a score equal or higher than this")
    parser.add_argument("--min_fuzzies", type=int, help="Augment sentence if it has at least this many fuzzies")
    parser.add_argument("--max_fuzzies", type=int, help="Augment the sentence with at most this many fuzzies (use n best matches if more than max fuzzies found)") 

    # Parse the arguments
    args = parser.parse_args()
    print(args)
    main(args)
