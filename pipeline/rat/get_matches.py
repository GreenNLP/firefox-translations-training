import argparse
import gzip
import os
from random import shuffle

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
    mix_scores = None
    fuzzy_buckets = {}
    if args.mix_score_file:
        mix_scores = read_score_file(args.mix_score_file)

    #if index set is the same as test, don't read it twice
    if (args.src_sentence_file == args.index_src_sentence_file):
        index_src_sentences = src_sentences
        index_trg_sentences = trg_sentences
    else:
        index_src_sentences = read_sentence_file(args.index_src_sentence_file)
        index_trg_sentences = read_sentence_file(args.index_trg_sentence_file)

    with gzip.open(args.src_augmented_file,'wt') as src_output_file, \
        gzip.open(args.trg_augmented_file,'wt') as trg_output_file:
        print("Augmenting with fuzzies")
        augmented_count = 0
        for index, sentence in enumerate(src_sentences):
            if args.lines_to_augment and augmented_count == args.lines_to_augment:
                break
            if index in scores:
                score_indices = scores[index]
                # shuffle to avoid too many high fuzzies
                shuffle(score_indices)
                corresponding_sentences = [
                    (index_src_sentences[i-1],index_trg_sentences[i-1],score) for score,i in
                    score_indices if score >= args.min_score and score <= args.max_score][0:args.max_fuzzies]
            else:
                corresponding_sentences = []
            # mix means using one match from an alternative source (used with targetsim to have one match that is guaranteed to be reflected on the target side)
            if mix_scores and index in mix_scores:
                score_indices = mix_scores[index]
                mix_corresponding_sentences = [
                    (index_src_sentences[i-1],index_trg_sentences[i-1],score) for score,i in
                    mix_score_indices if score >= args.min_score and score <= args.max_score][0]
                if corresponding_sentences:
                    corresponding_sentences[0] = mix_corresponding_sentences[0]
                else:
                    corresponding_sentences = mix_corresponding_sentences

            #mix up matches to prevent the model from learning an implicit order
            if len(corresponding_sentences) > 1:
                shuffle(corresponding_sentences)

            # keep track of fuzzy counts
            for fuzzy in corresponding_sentences:
                fuzzy_bucket = int(fuzzy[2]*10)
                if fuzzy_bucket in fuzzy_buckets:
                    fuzzy_buckets[fuzzy_bucket] += 1
                else:
                    fuzzy_buckets[fuzzy_bucket] = 1

            if len(corresponding_sentences) >= args.min_fuzzies:
                if args.include_source:
                    fuzzies = [f"{x[0]}{args.source_separator}{x[1]}{args.target_separator}" for x in corresponding_sentences]
                    src_output_file.write(f"{fuzzies}{sentence}\n")
                    trg_output_file.write(trg_sentences[index]+"\n")
                else:
                    target_fuzzies = [x[1] for x in corresponding_sentences]
                    src_output_file.write(f"{args.target_separator.join(target_fuzzies)}{args.target_separator}{sentence}\n")
                    trg_output_file.write(trg_sentences[index]+"\n")
                augmented_count += 1
            else:
                if not args.exclude_non_augmented:
                    src_output_file.write(f"{sentence}\n")
                    trg_output_file.write(trg_sentences[index]+"\n")
                    augmented_count += 1

    print(fuzzy_buckets)

if __name__ == "__main__":
    # Set up argument parsing
    parser = argparse.ArgumentParser(description="Augment data with fuzzies from index.")
    parser.add_argument("--src_sentence_file", help="Path to the file containing the source sentences that should be augmented with fuzzies.")
    parser.add_argument("--trg_sentence_file", help="Path to the file containing the target sentences that should be augmented with fuzzies.")
    parser.add_argument("--score_file", help="Path to the file containing the indices of fuzzies found for each sentence in the sentence file")
    parser.add_argument("--mix_score_file", help="Path to the file containing the indices of the mix fuzzies found for each sentence in the sentence file. One of these fuzzies is used alongside the normal fuzzies when augmenting a sentence")
    parser.add_argument("--src_augmented_file", help="Path to save the source file augmented with fuzzies.")
    parser.add_argument("--trg_augmented_file", help="Path to save the target file augmented with fuzzies.")
    parser.add_argument("--index_src_sentence_file", help="Path to the file containing the source sentences corresponding to the fuzzy indices in the score file")
    parser.add_argument("--index_trg_sentence_file", help="Path to the file containing the target sentences corresponding to the fuzzy indices in the score file")
    parser.add_argument("--source_separator", default="FUZZY_BREAK", help="Separator token that separates the source side of fuzzies from other fuzzies and the source sentence")
    parser.add_argument("--target_separator", default="FUZZY_BREAK", help="Separator token that separates the target side of fuzzies from other fuzzies and the source sentence")
    parser.add_argument("--min_score", type=float, help="Only consider fuzzies that have a score equal or higher than this")
    parser.add_argument("--max_score", type=float, help="Only consider fuzzies that have a score equal or lower than this")
    parser.add_argument("--min_fuzzies", type=int, help="Augment sentence if it has at least this many fuzzies")
    parser.add_argument("--max_fuzzies", type=int, help="Augment the sentence with at most this many fuzzies (use n best matches if more than max fuzzies found)") 
    parser.add_argument("--lines_to_augment", type=int, default=-1, help="Augment this many lines, default is all lines") 
    parser.add_argument("--include_source", action="store_true", help="Also include source in the augmented line") 
    parser.add_argument("--exclude_non_augmented", action="store_true", help="Do not include non-augmented in the output") 
    # Parse the arguments
    args = parser.parse_args()
    print(args)
    main(args)
