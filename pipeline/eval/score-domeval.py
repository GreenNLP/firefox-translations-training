import os
import argparse
import sacrebleu
import csv

def parse_args():
    parser = argparse.ArgumentParser(description="Generate BLEU and chrF scores for domain-specific translations.")
    
    parser.add_argument("input_dir", help="Input directory containing the test files.")
    parser.add_argument("report_file", help="Output report file.")
    parser.add_argument("src_lang", help="Three-letter source language code.")
    parser.add_argument("trg_lang", help="Three-letter target language code.")
    parser.add_argument("domeval_ids", help="Path to TSV file containing domain evaluation IDs (with domain names).")
    
    return parser.parse_args()

def read_file_lines(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        return [line.strip() for line in f.readlines()]

def write_report(report_file, report_content):
    with open(report_file, 'w', encoding='utf-8') as f:
        f.write(report_content)

def calculate_sacrebleu(reference, translations):
    bleu_score = sacrebleu.corpus_bleu(translations, [reference])
    chrf_score = sacrebleu.corpus_chrf(translations, [reference])
    return bleu_score, chrf_score

def process_domain_files(domain, input_dir, trg_lang, ref_lines, report_content):
    # Filenames
    fin_file = os.path.join(input_dir, f"{domain}.domeval.fin")
    translated_fuzzies_file = os.path.join(input_dir, f"{domain}.domeval.translated_fuzzies")
    linenum_file = os.path.join(input_dir, f"{domain}.domeval.linenum")
    
    # Process fin file (full test set translation)
    fin_lines = read_file_lines(fin_file)
    bleu_fin, chrf_fin = calculate_sacrebleu(ref_lines, fin_lines)
    report_content += f"Domain: {domain} - Full test set (fin)\n"
    report_content += f"BLEU: {bleu_fin.score}\nchrF: {chrf_fin.score}\n\n"
    
    # Process translated fuzzies
    fuzzy_lines = read_file_lines(translated_fuzzies_file)
    linenum_lines = [int(line.strip()) for line in read_file_lines(linenum_file)]
    fuzzy_ref_lines = [ref_lines[linenum] for linenum in linenum_lines]
    
    bleu_fuzzy, chrf_fuzzy = calculate_sacrebleu(fuzzy_ref_lines, fuzzy_lines)
    report_content += f"Domain: {domain} - Fuzzy subset\n"
    report_content += f"BLEU: {bleu_fuzzy.score}\nchrF: {chrf_fuzzy.score}\n\n"
    
    return report_content

def process_domeval_ids(input_dir, trg_lang, tsv_file, ref_file_path, report_content):
    # Read the TSV file into a dictionary mapping each line number to its domain
    domain_dict = {}
    with open(tsv_file, 'r', encoding='utf-8') as f:
        reader = csv.reader(f, delimiter='\t')
        for idx, row in enumerate(reader):
            domain_dict[idx] = row[0]

    # Read the aligned files: reference translations and domain-specific translations
    ref_lines = read_file_lines(ref_file_path)
    all_fin_lines = {}
    
    for domain in set(domain_dict.values()):
        domain_fin_file = os.path.join(input_dir, f"{domain}.domeval.fin")
        if os.path.exists(domain_fin_file):
            all_fin_lines[domain] = read_file_lines(domain_fin_file)

    # Initialize a dictionary to hold domain-specific sentences for evaluation
    domain_specific_refs = {}
    domain_specific_trans = {}

    for idx, domain in domain_dict.items():
        if domain not in domain_specific_refs:
            domain_specific_refs[domain] = []
            domain_specific_trans[domain] = []

        domain_specific_refs[domain].append(ref_lines[idx])
        domain_specific_trans[domain].append(all_fin_lines[domain][idx])

    # Now calculate sacrebleu for domain-specific translations
    for domain in domain_specific_refs:
        ref_lines = domain_specific_refs[domain]
        fin_lines = domain_specific_trans[domain]
        
        bleu_domain, chrf_domain = calculate_sacrebleu(ref_lines, fin_lines)
        report_content += f"Domain: {domain} - Domain-specific subset\n"
        report_content += f"BLEU: {bleu_domain.score}\nchrF: {chrf_domain.score}\n\n"
    
    return report_content

def main():
    # Parse the arguments
    args = parse_args()
    
    # Prepare the report content
    report_content = ""

    # Read the reference file domeval.[trg].ref
    ref_file_path = os.path.join(args.input_dir, f"domeval.{args.trg_lang}.ref")

    # Process domeval_ids TSV file (and align domeval.[trg].ref with [domain].domeval.fin)
    report_content = process_domeval_ids(args.input_dir, args.trg_lang, args.domeval_ids, ref_file_path, report_content)

    # Write report to file
    write_report(args.report_file, report_content)

if __name__ == "__main__":
    main()
