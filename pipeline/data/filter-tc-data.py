import argparse
import gzip
import os
from collections import defaultdict

def process_files(src_file, trg_file, id_file, score_file, min_score, domain_eval_lines, output_dir):
    print(f"Creating output dir in {output_dir}")
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    train_src_path = f"{output_dir}/{os.path.basename(src_file)}"
    train_trg_path = f"{output_dir}/{os.path.basename(trg_file)}"
    
    eval_lines = defaultdict(lambda: ([], []))  # dictionary to store eval lines per corpus
    domain_files = {}  # dictionary to store open file handles for domains
    
    with gzip.open(src_file, 'rt', encoding='utf-8') as src, \
         gzip.open(trg_file, 'rt', encoding='utf-8') as trg, \
         gzip.open(id_file, 'rt', encoding='utf-8') as ids, \
         gzip.open(score_file, 'rt', encoding='utf-8') as scores, \
         gzip.open(train_src_path, 'wt', encoding='utf-8') as train_src, \
         gzip.open(train_trg_path, 'wt', encoding='utf-8') as train_trg:

        eval_counts = defaultdict(int)
        
        for src_line, trg_line, id_line, score_line in zip(src, trg, ids, scores):
            score = float(score_line.strip().split("\t")[-1])
            if score < min_score:
                continue

            corpus_name = id_line.split("\t")[0]

            # Open domain-specific files if not already opened
            if corpus_name not in domain_files:
                domain_src_path = f"{output_dir}/{corpus_name}.train.src.gz"
                domain_trg_path = f"{output_dir}/{corpus_name}.train.trg.gz"
                domain_files[corpus_name] = (
                    gzip.open(domain_src_path, 'wt', encoding='utf-8'),
                    gzip.open(domain_trg_path, 'wt', encoding='utf-8')
                )
            

            if domain_eval_lines > 0 and eval_counts[corpus_name] < domain_eval_lines:
                eval_lines[corpus_name][0].append(src_line)
                eval_lines[corpus_name][1].append(trg_line)
                eval_counts[corpus_name] += 1
            else:
                domain_files[corpus_name][0].write(src_line)
                domain_files[corpus_name][1].write(trg_line)
                train_src.write(src_line)
                train_trg.write(trg_line)

    # Write the eval data to respective files
    for corpus_name, (src_lines, trg_lines) in eval_lines.items():
        eval_file_path = f"{output_dir}/{corpus_name}.eval.gz"
        with gzip.open(eval_file_path, 'wt', encoding='utf-8') as eval_file:
            for src_line, trg_line in zip(src_lines, trg_lines):
                eval_file.write(src_line)
                eval_file.write(trg_line)

    # Close all domain-specific files
    for src_file, trg_file in domain_files.values():
        src_file.close()
        trg_file.close()

def main():
    parser = argparse.ArgumentParser(description='Process and filter corpus data based on score.')
    parser.add_argument('--source_corpus', required=True, help='Path to the source corpus file (gzipped)')
    parser.add_argument('--target_corpus', required=True, help='Path to the target corpus file (gzipped)')
    parser.add_argument('--id_file', required=True, help='Path to the ID file')
    parser.add_argument('--score_file', required=True, help='Path to the score file')
    parser.add_argument('--min_score', type=float, required=True, help='Minimum score for filtering (0 to 1)')
    parser.add_argument('--domain_eval_lines', type=int, required=True, help='Number of domain-specific evaluation lines to extract (0 to disable)')
    parser.add_argument('--output_dir', required=True, help='Directory to store the output files')

    args = parser.parse_args()

    print("Filtering Tatoeba-Challenge corpus based on Bicleaner-AI scores")

    process_files(
        args.source_corpus,
        args.target_corpus,
        args.id_file,
        args.score_file,
        args.min_score,
        args.domain_eval_lines,
        args.output_dir
    )

if __name__ == "__main__":
    main()

