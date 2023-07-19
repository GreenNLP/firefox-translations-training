import json
import gzip
import ast
import contextlib
import argparse

def count_terms(output_nbest, line_terms, output_lang):
    hyp_term_count_for_output = []
    for hypothesis in output_nbest:
        term_count = 0
        for line_term in line_terms:
            if line_term[args.output_lang].lower() in hypothesis.lower():
                term_count += 1
        hyp_term_count_for_output.append((hypothesis,term_count))
    return hyp_term_count_for_output

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Picks the translation with most correct terms from a list of translations. Translations higher up in the list are assumed to be better.")
    parser.add_argument('--system_outputs', nargs='+', default=[], help="List of system output files, containing nbest lists")
    parser.add_argument("--terms", type=str,
                        help="For each line of output, the source and target indexed by lang code for the spans that should appear in target .")    
    parser.add_argument("--mixture_output", type=str,
                        help="Output file for the best term translations.")
    parser.add_argument("--output_lang", type=str,
                        help="The language code of the output.")
    parser.add_argument("--nbest_size", type=int,
                        help="The size of the nbest list.")
    parser.add_argument("--verbose", action='store_true',default=False,
                        help="Show extra info on the selected translations.")

    args = parser.parse_args()
    
    missing_terms = 0
    all_terms = 0
    jsonl_terms = args.terms.endswith(".jsonl")
   
    best_term_translations = []
    with contextlib.ExitStack() as system_output_stack, \
        open(args.terms,'rt') if jsonl_terms else gzip.open(args.terms,'r') as terms, \
        open(args.mixture_output,'wt') as mixture_output:
        outputs = [system_output_stack.enter_context(open(fname,"rt")) for fname in args.system_outputs]
        for term_line in terms:
            if args.verbose:
                mixture_output.write(term_line)
            output_nbests_for_line = [[next(output) for _ in range(args.nbest_size)] for output in outputs]
            if not term_line or term_line.isspace():
                if args.verbose:
                    mixture_output.write(f"{args.system_outputs[0]}: {output_nbests_for_line[0][0]}")
                else:
                    mixture_output.write(f"{output_nbests_for_line[0][0]}")
                continue
            print(term_line)
            line_terms = json.loads(term_line)
            hyp_term_count = []
            for output_nbest in output_nbests_for_line:
                output_term_counts = count_terms(output_nbest, line_terms, args.output_lang)
                hyp_term_count.append(output_term_counts)

            # find the translation with most terms correct
            best_translation = None
            for term_count_limit in reversed(range(0,len(line_terms)+1)):
                if best_translation:
                    break
                for output_index,output_nbest_counts in enumerate(hyp_term_count):
                    best_translation = next((x[0] for x in output_nbest_counts if x[1] == term_count_limit), None)
                    if best_translation:
                        system_output = args.system_outputs[output_index]
                        break
            if args.verbose:
                mixture_output.write(f"{system_output}: {best_translation}")
            else:
                mixture_output.write(f"{best_translation}")

