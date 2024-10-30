import argparse
import gzip
import re
import sacrebleu

def split_on_fuzzy_break(source, target):
    results = []

    #check if fuzzy indexes are used (this is hacky and it should be an argument to the script, but time is short)
    fuzzy_indexes = re.search("FUZZY_BREAK_\d",source[0])

    # Process each sentence pair

    for src_sent, tgt_sent in zip(source, target):
        pseudo_refs = []
        # Split the source sentence by 'FUZZY_BREAK'
        if fuzzy_indexes:
            parts = re.split("FUZZY_BREAK_\d", src_sent)
        else:
            parts = src_sent.split('FUZZY_BREAK')
        for index,fuzzy in enumerate(parts[0:-1]):
            pseudo_refs.append(fuzzy)
        results.append(pseudo_refs)
    max_fuzzy_count = max([len(x) for x in results])
    # fill up all result lines to the max fuzzy count to construct full pseudorefs
    for res in results:
        if len(res) < max_fuzzy_count:
            for i in range(0, max_fuzzy_count-len(res)):
                res.append(res[-1])

    pseudo_files = []
    for fuzzy_count in range(0,max_fuzzy_count):
        pseudo_files.append([])
        pseudo_files[fuzzy_count] = [x[fuzzy_count] for x in results]
    return pseudo_files
    
def extract_fuzzy_bands(source_sentence):
    """
    Extracts all fuzzy bands (if any) from the source sentence.
    Returns the average fuzzy band (if any) and a boolean indicating
    if any fuzzy band was found.
    """
    fuzzy_pattern = r'FUZZY_BREAK(?:_(\d))?'
    matches = re.findall(fuzzy_pattern, source_sentence)

    if matches:
        fuzzy_bands = [int(m) for m in matches if m.isdigit()]
        if fuzzy_bands:
            average_band = sum(fuzzy_bands) / len(fuzzy_bands)
            return average_band, True
    return None, False

def process_files(max_count, src_file_path, target_file_path):
    fuzzy_band_dict = {}
    all_fuzzies = []
    with gzip.open(src_file_path, 'rt', encoding='utf-8') as src_file, \
         gzip.open(target_file_path, 'rt', encoding='utf-8') as tgt_file:
        fuzzy_line_count = 0
        for src_line, tgt_line in zip(src_file, tgt_file):
            if 'FUZZY_BREAK' in src_line:
                avg_fuzzy_band, found_fuzzy_band = extract_fuzzy_bands(src_line)

                # Add to fuzzy band dictionary if found
                if found_fuzzy_band:
                    fuzzy_band = round(avg_fuzzy_band)
                    if fuzzy_band not in fuzzy_band_dict:
                        fuzzy_band_dict[fuzzy_band] = [(src_line,tgt_line)]
                    fuzzy_band_dict[fuzzy_band].append((src_line,tgt_line))
                fuzzy_line_count += 1
                all_fuzzies.append((src_line,tgt_line))

            # Stop if the max count is reached
            if fuzzy_line_count >= max_count:
                break

    # Print the counts of sentence pairs for each fuzzy band
    print("Fuzzy Band Counts:")
    for band, sents in sorted(fuzzy_band_dict.items()):
        print(f"Fuzzy Band {band}: {len(sents)} sentence pairs")
        
    source = [x[0] for x in all_fuzzies]
    translations = [x[1] for x in all_fuzzies]
    pseudo_refs = split_on_fuzzy_break(source,translations)
    copyrate_metric = sacrebleu.CopyRate()
    copyrate = copyrate_metric.corpus_score(translations, pseudo_refs)
    copyrate_score = copyrate.score
    print(f"Copyrate score for all fuzzies: {copyrate_score}")

def main():
    parser = argparse.ArgumentParser(description="Process gzipped files and filter sentence pairs with FUZZY_BREAK.")
    parser.add_argument('max_count', type=int, help='Maximum number of sentence pairs to process.')
    parser.add_argument('src_file_path', type=str, help='Path to the gzipped source file.')
    parser.add_argument('target_file_path', type=str, help='Path to the gzipped target file.')

    args = parser.parse_args()

    process_files(args.max_count, args.src_file_path, args.target_file_path)

if __name__ == '__main__':
    main()
