import json
import gzip
import ast
import argparse

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Scores test set based on the presence of the required terms")
    parser.add_argument("--system_output", type=str,
                        help="Output of the system.")
    parser.add_argument("--terms", type=str,
                        help="For each line of output, the source and target indexed by lang code for the spans that should appear in target .")
    parser.add_argument("--output_lang", type=str,
                        help="The language code of the output.")
    parser.add_argument("--score_only", type=str,
                        help="Only output score.")

    args = parser.parse_args()
    
    missing_terms = 0
    all_terms = 0
    jsonl_terms = args.terms.endswith(".jsonl")
    with open(args.system_output,'rt') as output, \
         open(args.terms,'rt') if jsonl_terms else gzip.open(args.terms,'r') as terms:
        for line in output:
            term_line = terms.readline()
            if not term_line or term_line.isspace():
                continue
            if jsonl_terms:
                line_terms = json.loads(term_line)
            else:
                line_terms = [{args.source_lang: " ".join(x[4]),args.target_lang: " ".join(x[5])} for x in ast.literal_eval(term_line)]
            for line_term in line_terms:
                all_terms += 1
                if line_term[args.output_lang].lower() not in line.lower():
                    missing_terms += 1
                    if not args.score_only:
                        print(f"term missing: {line_term[args.output_lang]}")
                        print(f"line: {line}")

    if not args.score_only:
        print(f"missing terms: {missing_terms} out of {all_terms}")
    print(f"{1-missing_terms/all_terms}")
