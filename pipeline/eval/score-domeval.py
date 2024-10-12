import os
import argparse
import sacrebleu
import csv
import gzip

def parse_args():
    parser = argparse.ArgumentParser(description="Generate BLEU and chrF scores for domain-specific translations.")
    
    parser.add_argument("--input_dir", help="Input directory containing the test files.")
    parser.add_argument("--report_file", help="Output report file.")
    parser.add_argument("--src_lang", help="Three-letter source language code.")
    parser.add_argument("--trg_lang", help="Three-letter target language code.")
    parser.add_argument("--system_id", help="ID of the system used to translate domeval.")
    parser.add_argument("--domeval_ids", help="Path to TSV file containing domain evaluation IDs (with domain names).")
    
    return parser.parse_args()

def read_file_lines(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        return [line.strip() for line in f.readlines()]

def calculate_sacrebleu(reference, translations):
    bleu_score = sacrebleu.corpus_bleu(translations, [reference])
    chrf_score = sacrebleu.corpus_chrf(translations, [reference])
    return bleu_score, chrf_score

def process_domain_files(domain, input_dir, trg_lang, ref_lines, report_file, system_id):
    # Filenames
    trg_file = os.path.join(input_dir, f"{domain}-domeval.{trg_lang}")
    translated_fuzzies_file = os.path.join(input_dir, f"{domain}-domeval.translated_fuzzies")
    linenum_file = os.path.join(input_dir, f"{domain}-domeval.linenum")
    
    # Process trg file (full test set translation)
    #trg_lines = read_file_lines(trg_file)
    #bleu_trg, chrf_trg = calculate_sacrebleu(ref_lines, trg_lines)
    #report_file.write(f"full_domeval\t{domain}\t{bleu_trg.score}\t{chrf_trg.score}\n")
    
    # Process translated fuzzies
    fuzzy_lines = read_file_lines(translated_fuzzies_file)
    linenum_lines = [int(line.split(":")[0].strip()) for line in read_file_lines(linenum_file)]
    fuzzy_ref_lines = [ref_lines[linenum-1] for linenum in linenum_lines]
    
    bleu_fuzzy, chrf_fuzzy = calculate_sacrebleu(fuzzy_ref_lines, fuzzy_lines)
    report_file.write(f"all_fuzzies\t{domain}\t{bleu_fuzzy.score}\t{chrf_fuzzy.score}\tonly_fuzzies\t{len(fuzzy_lines)}\t{system_id}\n")
    
def process_domeval_ids(input_dir, trg_lang, tsv_file, ref_file_path, report_file, system_id):
    # Read the TSV file into a dictionary mapping each line number to its domain
    id_to_domain_dict = {}
    domain_to_id_dict = {}
    with gzip.open(tsv_file, 'rt', encoding='utf-8') as f:
        reader = csv.reader(f, delimiter='\t')
        for idx, row in enumerate(reader):
            domain = row[0]
            id_to_domain_dict[idx] = domain
            if domain not in domain_to_id_dict:
                domain_to_id_dict[domain] = set()
            domain_to_id_dict[domain].add(idx)

    # Read the nofuzzies.[trg] file
    nofuzzies_trg_path = os.path.join(input_dir, f"nofuzzies.{trg_lang}")
    nofuzzies_trg_lines = read_file_lines(nofuzzies_trg_path)

    # Read the aligned files: reference translations and domain-specific translations
    all_ref_lines = read_file_lines(ref_file_path)
    all_trg_lines = {}
    
    #add train and all_filtered here
    domains = set(id_to_domain_dict.values())

    for domain in domains:
        domain_trg_file = os.path.join(input_dir, f"{domain}-domeval.{trg_lang}")
        if os.path.exists(domain_trg_file):
            all_trg_lines[domain] = read_file_lines(domain_trg_file)

    # Initialize a dictionary to hold domain-specific sentences for evaluation
    domain_specific_refs = {}
    domain_specific_trans = {}
    domain_specific_nofuzzies = {}
    
    index_domains = all_trg_lines.keys()

    # open fuzzy linenum file to get domain-specific fuzzy counts
    domain_to_fuzzy_id = {}

    for index_domain in index_domains:
        domain_to_fuzzy_id[index_domain] = {}
        with open(os.path.join(input_dir, f"{index_domain}-domeval.linenum"),'r') as linenum_file:
            linenum_lines = {int(line.split(":")[0].strip())-1 for line in linenum_file.readlines()}
            for domain in domains:
                domain_to_fuzzy_id[index_domain][domain] = linenum_lines.intersection(domain_to_id_dict[domain])
            
    for idx, domain in id_to_domain_dict.items():
        if domain not in all_trg_lines.keys():
            continue
        #new domain initialization
        if domain not in domain_specific_refs:
            domain_specific_refs[domain] = []
            domain_specific_nofuzzies[domain] = []
            for index_domain in index_domains:
                if index_domain not in domain_specific_trans:
                    domain_specific_trans[index_domain] = {}
                if domain not in domain_specific_trans[index_domain]:
                    domain_specific_trans[index_domain][domain] = []

        domain_specific_refs[domain].append(all_ref_lines[idx])
        domain_specific_nofuzzies[domain].append(nofuzzies_trg_lines[idx])

        for index_domain in index_domains:
            domain_specific_trans[index_domain][domain].append(all_trg_lines[index_domain][idx])
        

    # Now calculate sacrebleu for domain-specific translations
    for domain in domain_specific_refs:
        print(f"processing {domain}")
        ref_lines = domain_specific_refs[domain]        
        
        for index_domain in index_domains:
            domain_fuzzies = domain_to_fuzzy_id[index_domain][domain]
            fuzzy_count = len(domain_fuzzies)
            if fuzzy_count < 20:
                continue
            trg_lines = domain_specific_trans[index_domain][domain]
            bleu_domain, chrf_domain = calculate_sacrebleu(ref_lines, trg_lines)
            report_file.write(f"{domain}\t{index_domain}\t{bleu_domain.score}\t{chrf_domain.score}\tall\t{fuzzy_count}\t{system_id}\n")

            fuzzy_ref_lines = [all_ref_lines[linenum-1] for linenum in domain_fuzzies]
            fuzzy_trg_lines = [all_trg_lines[index_domain][linenum-1] for linenum in domain_fuzzies]

            bleu_domain_fuzzy, chrf_domain_fuzzy = calculate_sacrebleu(fuzzy_ref_lines, fuzzy_trg_lines)
            report_file.write(f"{domain}\t{index_domain}\t{bleu_domain_fuzzy.score}\t{chrf_domain_fuzzy.score}\tonly_fuzzies\t{fuzzy_count}\t{system_id}\n")

        nofuz_trg_lines = domain_specific_nofuzzies[domain]
        no_fuz_bleu_domain, no_fuz_chrf_domain = calculate_sacrebleu(ref_lines, nofuz_trg_lines)
        report_file.write(f"{domain}\tnofuzzies\t{no_fuz_bleu_domain.score}\t{no_fuz_chrf_domain.score}\tall\t0\t{system_id}\n")

def main():
    # Parse the arguments
    args = parse_args()
    
    # Prepare the report content

    with open(args.report_file,'wt') as report_file:

        # Read the reference file domeval.[trg].ref
        ref_file_path = os.path.join(args.input_dir, f"domeval.{args.trg_lang}.ref")

        for file_name in os.listdir(args.input_dir):
            if file_name.endswith(f"-domeval.{args.trg_lang}"):
                domain = file_name.replace(f"-domeval.{args.trg_lang}","")
                process_domain_files(domain, args.input_dir, args.trg_lang, read_file_lines(ref_file_path), report_file, args.system_id)

        # Process domeval_ids TSV file (and align domeval.[trg].ref with [domain].domeval.[trg])
        process_domeval_ids(args.input_dir, args.trg_lang, args.domeval_ids, ref_file_path, report_file, args.system_id)

if __name__ == "__main__":
    main()
