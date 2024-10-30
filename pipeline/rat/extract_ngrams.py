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

def get_common_token_sequences(tokens1, tokens2, min_length=5):
    """Find the single longest common sequence of tokens between two token lists using difflib."""
    seq_matcher = difflib.SequenceMatcher(None, tokens1, tokens2)
    
    matches = []
    #strip punctuation
    for match in seq_matcher.get_matching_blocks():
        match_tokens = tokens1[match.a:match.a + match.size]
        match_start_pos = match.b
        match_size = match.size

        if match_size < min_length:
            continue

        if match_tokens[0] == ',':
            match_tokens = match_tokens[1:]
            match_start_pos += 1
            match_size -= 1
        
        if match_tokens[-1] == ',':
            match_tokens = match_tokens[0:-1]
            match_size -= 1
        
        if match_size >= min_length:
            matches.append(((match_start_pos,match_start_pos+match_size), match_tokens)) 

    # Extract the longest sequence from tokens1 based on the match
    return matches if len(matches) > 0 else []

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

        # Tokenize source sentence and source match text. Note that when using targetsim, the input files are already reversed, so no need to do changes here
        tokens1 = src_tokenizer.tokenize(normalizer.normalize(source_sentence))
        tokens2 = tokenized_src_match
            
        # Find the longest common sequence of tokens
        common_sequences = get_common_token_sequences(tokens1, tokens2)
        for (lcs_pos,lcs_tokens) in common_sequences:
            yield (tokenized_src_match, tokenized_trg_match, lcs_tokens, lcs_pos)
        i += 1  # Move to the next match item

def generate_alignments(tok_src_path, tok_trg_path, eflomal_priors_path):
    aligner = eflomal.Aligner()
    fwd_path = tok_src_path.replace(".gz",".fwd")
    rev_path = tok_src_path.replace(".gz",".rev")
    with gzip.open(tok_src_path, 'rt', encoding='utf-8') as src_data, \
        gzip.open(tok_trg_path, 'rt', encoding='utf-8') as trg_data, \
        open(eflomal_priors_path, 'r', encoding='utf-8') as priors_data:
        
        # Align with priors
        aligner.align(
            src_data, trg_data,
            links_filename_fwd=fwd_path, links_filename_rev=rev_path,
            priors_input=priors_data)
    return (fwd_path,rev_path)

def main(source_file, target_file, match_file, priors_file, targetsim, src_lang, trg_lang, output_file=None):
    src_tokenizer = sacremoses.MosesTokenizer(lang=langcodes.standardize_tag(src_lang))
    trg_tokenizer = sacremoses.MosesTokenizer(lang=langcodes.standardize_tag(trg_lang))
    src_detokenizer = sacremoses.MosesDetokenizer(lang=langcodes.standardize_tag(src_lang))
    trg_detokenizer = sacremoses.MosesDetokenizer(lang=langcodes.standardize_tag(trg_lang))
    normalizer = sacremoses.MosesPunctNormalizer()
    if not targetsim:
        # temp dir to store intermediate eflomal files 
        temp_dir = os.path.join(os.path.dirname(source_file),"eflomal_tmp")
        if not targetsim and not os.path.exists(temp_dir):
            os.makedirs(temp_dir)
        eflomal_src_file = os.path.join(temp_dir,os.path.basename(source_file).replace("gz","tok.gz"))
        eflomal_trg_file = os.path.join(temp_dir,os.path.basename(target_file).replace("gz","tok.gz"))
        eflomal_match_file = os.path.join(temp_dir,os.path.basename(source_file).replace("gz","match.gz"))
    else:
        aligner = None

    if output_file:
        ngram_file = output_file
    else:
        ngram_file = source_file.replace(".gz",".ngrams.gz")
        # this is just to make sure the source file is not overwritten accidentally
        if ngram_file == source_file:
            ngram_file = source_file + ".ngrams.gz"
    

    # Open all files in the main function using the with statement
    with gzip.open(ngram_file, 'wt', encoding='utf-8') as ngram_f:
        """with gzip.open(source_file, 'rt', encoding='utf-8') as source_f, \
            gzip.open(target_file, 'rt', encoding='utf-8') as target_f, \
            gzip.open(match_file, 'rt', encoding='utf-8') as match_f, \
            gzip.open(eflomal_src_file, 'wt', encoding='utf-8') if not targetsim else nullcontext() as eflomal_src, \
            gzip.open(eflomal_trg_file, 'wt', encoding='utf-8') if not targetsim else nullcontext() as eflomal_trg, \
            gzip.open(eflomal_match_file, 'wt', encoding='utf-8') if not targetsim else nullcontext() as eflomal_matches:
            # Iterate over lines of source, target, and match files together
            for index, (source_sentence, target_sentence, match_line) in enumerate(zip(source_f, target_f, match_f)):
                if len(match_line.strip())==0:
                    if targetsim:
                        ngram_f.write("\n")
                    continue
                source_sentence = source_sentence.strip()
                target_sentence = target_sentence.strip()
                match_line = match_line.strip()

                # Process each match line along with corresponding source/target sentences
                match_items = process_match_line(match_line, source_sentence, target_sentence, targetsim, src_tokenizer, trg_tokenizer, normalizer)

                ngrams = []
                for (tokenized_src_match, tokenized_trg_match, lcs_tokens, lcs_pos) in match_items:
                    if targetsim:
                        # with targetsim, input files are reversed, so use src detokenizer
                        ngrams.append(src_detokenizer.detokenize(lcs_tokens))
                    else:
                        eflomal_src.write(f'{" ".join(tokenized_src_match)}\n')
                        eflomal_trg.write(f'{" ".join(tokenized_trg_match)}\n')
                        eflomal_matches.write(json.dumps((index, lcs_pos, lcs_tokens))+"\n")
                if targetsim:
                    if ngrams:
                        # these are actually full matches, but that messes with the rest of the pipeline, so use 0.99
                        ngram_f.write("\t".join([f"1\t00000={ngram} ||| targetsim" for ngram in set(ngrams)])+"\n")
                    else:
                        ngram_f.write("\n")
        """
        # if source sim, align the files in eflomal_tmp, then look for correspondign target tokens for the source tokens in the lcs (dropping tokens as necessary, as long as the match remains fairly long)
        if not targetsim:
            #(fwd_align_path,rev_align_path) = generate_alignments(eflomal_src_file, eflomal_trg_file, priors_file)
            fwd_align_path = eflomal_src_file.replace(".gz",".fwd")
            rev_align_path = eflomal_src_file.replace(".gz",".fwd")
            with gzip.open(eflomal_src_file, 'rt', encoding='utf-8') as source_f, \
                gzip.open(eflomal_trg_file, 'rt', encoding='utf-8') as target_f, \
                gzip.open(eflomal_match_file, 'rt', encoding='utf-8') as match_f, \
                open(fwd_align_path,'r') as fwd_alignment_f, \
                open(rev_align_path,'r') as rev_alignment_f:
                line_matches_per_line = []
                # this is to make sure that lines with no matches are included in the result file
                last_index = 0
                for (match_src, match_trg, fwd_alignment, rev_alignment, match) in zip(source_f, target_f, fwd_alignment_f, rev_alignment_f, match_f):
                    (index, lcs_pos, lcs_tokens) = json.loads(match)

                    if index > last_index:
                        #use the same output format as find_matches so that the augment script can be used without changes
                        ngram_f.write("\t".join([f"1\t00000={src_lcs} ||| {trg_lcs}" for (src_lcs,trg_lcs) in set(line_matches_per_line)])+"\n")
                        #write line break to result file, multiple line breaks in case of no match lines
                        for empty in range (last_index,index):
                            ngram_f.write("\n")
                        line_matches_per_line = []
                    
                    last_index = index

                    
                    fwd_aligment_dict = {int(x[0]): int(x[1]) for x in [y.split('-') for y in fwd_alignment.split()]}
                    rev_aligment_dict = {int(x[0]): int(x[1]) for x in [y.split('-') for y in rev_alignment.split()]}
                    source_lcs_indexes = list(range(lcs_pos[0], lcs_pos[1]))
                    target_lcs_indexes = [fwd_aligment_dict[x] for x in source_lcs_indexes if x in fwd_aligment_dict]
                    
                    target_to_source_lcs_indexes = [rev_aligment_dict[x] for x in target_lcs_indexes if x in rev_aligment_dict]
                    alignment_difference = set(source_lcs_indexes).difference(target_to_source_lcs_indexes)

                    # check for length of target ngram
                    if not target_lcs_indexes or max(target_lcs_indexes)-min(target_lcs_indexes) < 5:
                        pass
                    # sanity check for very different alignments
                    elif len(alignment_difference) > len(lcs_tokens):
                        pass
                    # sanity check for large gaps in alignment
                    elif max(target_lcs_indexes)-min(target_lcs_indexes) > len(target_lcs_indexes)*2:
                        pass
                    else:
                        line_match = (src_detokenizer.detokenize(match_src.split(" ")[min(source_lcs_indexes):max(source_lcs_indexes)]), trg_detokenizer.detokenize(match_trg.split(" ")[min(target_lcs_indexes):max(target_lcs_indexes)]))
                        if line_match not in line_matches_per_line:
                            line_matches_per_line.append(line_match)
                    
                        

if __name__ == "__main__":
    #TODO: add output file parameter
    parser = argparse.ArgumentParser(description="Find longest common token sequence between source/target sentences and match file.")
    parser.add_argument("--source_file", required=True, help="Path to the gzipped source sentence file")
    parser.add_argument("--target_file", required=True, help="Path to the gzipped target sentence file")
    parser.add_argument("--match_file", required=True, help="Path to the gzipped match file")
    parser.add_argument("--src_lang", required=True, help="Source lang, three-letter code")
    parser.add_argument("--trg_lang", required=True, help="Target lang, three-letter code")
    parser.add_argument("--targetsim", action='store_true', help="If set, compares with target sentences; otherwise, compares with source")
    parser.add_argument("--priors_file", required=True, help="Elfomal alignment priors")
    parser.add_argument("--output_file", required=True, help="Output score file path")
    args = parser.parse_args()

    main(args.source_file, args.target_file, args.match_file, args.priors_file, args.targetsim, args.src_lang, args.trg_lang, args.output_file)

