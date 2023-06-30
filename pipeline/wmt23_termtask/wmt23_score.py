import json
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
    with open(args.system_output,'rt') as output, open(args.terms,'rt') as terms:
        for line in output:
            term_line = terms.readline()
            if not term_line or term_line.isspace():
                continue
            line_terms = json.loads(term_line)
            for line_term in line_terms:
                all_terms += 1
                if line_term[args.output_lang] not in line:
                    missing_terms += 1
                    if not args.score_only:
                        print(f"term missing: {line_term[args.output_lang]}")
                        print(f"line: {line}")

    if not args.score_only:
        print(f"missing terms: {missing_terms} out of {all_terms}")
    print(f"{1-missing_terms/all_terms}")
