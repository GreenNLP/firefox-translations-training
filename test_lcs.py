import argparse
import re
import gzip
import difflib
import sacremoses
import langcodes
import eflomal
import pathlib
import os
import json
from contextlib import nullcontext

def longest_common_token_sequence(tokens1, tokens2):
    """Find the single longest common sequence of tokens between two token lists using difflib."""
    seq_matcher = difflib.SequenceMatcher(None, tokens1, tokens2)
    
    # Find the longest matching block
    match = max(seq_matcher.get_matching_blocks(), key=lambda m: m.size)

    # Extract the longest sequence from tokens1 based on the match
    return tokens1[match.a:match.a + match.size] if match.size > 0 else []

def process_match_line(line, source_sentence, target_sentence, targetsim, src_tokenizer, trg_tokenizer, normalizer):
    """Process a line in the match file and return the longest common sequence of tokens."""
    # Split the line into items by tabs
    items = re.split(r'\t+', line.strip())    
    i = 0
    while i < len(items):
        score = float(items[i])  # The score is the first tab-separated part
        i += 1  # Move to the next part
        
        # The next part will have the format [id]=[src] ||| [trg]
        match_info = items[i]
        match_id, match_text = match_info.split('=', 1)
        
        # Split match_text by '|||' to get source and target matches
        src_match, tgt_match = match_text.split('|||')

        tokenized_src_match = src_tokenizer.tokenize(normalizer.normalize(src_match.strip()))
        tokenized_trg_match = trg_tokenizer.tokenize(normalizer.normalize(tgt_match.strip()))

        if targetsim:
            # Tokenize target sentence and target match text
            tokens1 = trg_tokenizer.tokenize(normalizer.normalize(target_sentence))
            tokens2 = tokenized_trg_match
        else:
            # Tokenize source sentence and source match text
            tokens1 = src_tokenizer.tokenize(normalizer.normalize(source_sentence))
            tokens2 = tokenized_src_match
            
        # Find the longest common sequence of tokens
        lcs_tokens = longest_common_token_sequence(tokens1, tokens2)
        yield (tokenized_src_match, tokenized_trg_match, lcs_tokens)
        i += 1  # Move to the next match item


def main(source_file, target_file, match_file, priors_file, targetsim, src_lang, trg_lang):
    src_tokenizer = sacremoses.MosesTokenizer(lang=langcodes.standardize_tag(src_lang))
    trg_tokenizer = sacremoses.MosesTokenizer(lang=langcodes.standardize_tag(trg_lang))
    src_detokenizer = sacremoses.MosesDetokenizer(lang=langcodes.standardize_tag(src_lang))
    trg_detokenizer = sacremoses.MosesDetokenizer(lang=langcodes.standardize_tag(trg_lang))
    normalizer = sacremoses.MosesPunctNormalizer()
    if not targetsim:
        aligner = eflomal.Aligner()
    else:
        aligner = None

    # temp dir to store intermediate eflomal files 
    temp_dir = os.path.join(os.path.dirname(source_file),"eflomal_tmp")
    if not targetsim and not os.path.exists(temp_dir):
        os.makedirs(temp_dir)

    ngram_file = source_file.replace(".gz",".ngrams.gz")
    if ngram_file == source_file:
        ngram_file = source_file + ".ngrams"

    # Open all files in the main function using the with statement
    with gzip.open(source_file, 'rt', encoding='utf-8') as source_f, \
         gzip.open(target_file, 'rt', encoding='utf-8') as target_f, \
         gzip.open(match_file, 'rt', encoding='utf-8') as match_f, \
         gzip.open(ngram_file, 'wt', encoding='utf-8') as ngram_f, \
         gzip.open(os.path.join(temp_dir,"source.gz"), 'wt', encoding='utf-8') if not targetsim else nullcontext() as eflomal_src, \
         gzip.open(os.path.join(temp_dir,"target.gz"), 'wt', encoding='utf-8') if not targetsim else nullcontext() as eflomal_trg, \
         gzip.open(os.path.join(temp_dir,"matches.gz"), 'wt', encoding='utf-8') if not targetsim else nullcontext() as eflomal_matches:
        # Iterate over lines of source, target, and match files together
        for index, (source_sentence, target_sentence, match_line) in enumerate(zip(source_f, target_f, match_f)):
            if len(match_line.strip())==0:
                continue
            source_sentence = source_sentence.strip()
            target_sentence = target_sentence.strip()
            match_line = match_line.strip()

            # Process each match line along with corresponding source/target sentences
            match_items = process_match_line(match_line, source_sentence, target_sentence, targetsim, src_tokenizer, trg_tokenizer, normalizer)

            ngrams = []
            for (tokenized_src_match, tokenized_trg_match, lcs_tokens) in match_items:
                if targetsim:
                    ngrams.append(trg_detokenizer.detokenize(lcs_tokens))
                else:
                    eflomal_src.write(f"{tokenized_src_match}\n")
                    eflomal_trg.write(f"{tokenized_trg_match}\n")
                    eflomal_matches.write(json.dumps((index,lcs_tokens)))
            if targetsim:
                ngram_f.write("\t".join(ngrams)+"\n")

            #TODO: align the files in elfomal_tmp, then look for correspondign target tokens for the source tokens in the lcs (dropping tokens as necessary, as long as the match remains fairly long)


""".generate_eflomal_priors.py.swp            # align source to target
            priors_path = pathlib.Path(priors_file)
            align_matches = lambda x: aligner.align(
                [y[1] for y in x], [y[2] for y in x],
                links_filename_fwd=f"{priors_path.stem}.fwd", links_filename_rev=f"{priors_path.stem}.rev",
                priors_input=priors_file)

            align_matches(results)
"""

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Find longest common token sequence between source/target sentences and match file.")
    parser.add_argument("--source_file", required=True, help="Path to the gzipped source sentence file")
    parser.add_argument("--target_file", required=True, help="Path to the gzipped target sentence file")
    parser.add_argument("--match_file", required=True, help="Path to the gzipped match file")
    parser.add_argument("--src_lang", required=True, help="Source lang, three-letter code")
    parser.add_argument("--trg_lang", required=True, help="Target lang, three-letter code")
    parser.add_argument("--targetsim", action='store_true', help="If set, compares with target sentences; otherwise, compares with source")
    parser.add_argument("--priors_file", required=True, help="Elfomal alignment priors")
    args = parser.parse_args()

    main(args.source_file, args.target_file, args.match_file, args.priors_file, args.targetsim, args.src_lang, args.trg_lang)

