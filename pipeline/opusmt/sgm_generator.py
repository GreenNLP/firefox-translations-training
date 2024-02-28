import argparse
import json
import ast

def generate_output(input_file, terminology_file, source_lang_code, set_id, output_file):
    with open(input_file, 'r', encoding='utf-8') as f_input, \
            open(terminology_file, 'r', encoding='utf-8') as f_terminology, \
            open(output_file, 'w', encoding='utf-8') as f_output:
        
        f_output.write(f'<srcset setid="{set_id}" srclang="{source_lang_code}">\n')
        
        f_output.write('<doc sysid="ref" docid="CMU_1" genre="terminology" origlang="{}">\n'.format(source_lang_code))
        f_output.write('<p>\n')
        seg_id = 0
        term_id = 0
        for line, term_pairs_line in zip(f_input, f_terminology):
            line = line.strip()
            if not term_pairs_line.strip():
                continue
            terms = ast.literal_eval(term_pairs_line.strip())
            words = line.split()
            f_output.write('<seg id="{}"> '.format(seg_id))
            #TODO: this won't work if the terms are in different order in source and target. Record the indices and
            #terms here and then do the adding separately for both source and target when all terms have been processed
            for (target_indices, source_lemmas, target_lemmas, source_indices, source_surfs, target_surfs) in reversed(terms):
                words.insert(source_indices[0],'<term id="{}" type="src_original_and_tgt_original" src="{}" tgt="{}">'.format(
                    term_id, " ".join(source_lemmas)," ".join(target_lemmas)))
                term_id += 1
                 
            f_output.write(" ".join(words))
            f_output.write('</seg>\n')
            seg_id += 1

        f_output.write('</p>\n')
        f_output.write('</doc>\n')

        f_output.write('</srcset>')


def main():
    parser = argparse.ArgumentParser(description="Generate output XML file with terminology tagging.")
    parser.add_argument("input_file", help="Path to the input file containing lines of text.")
    parser.add_argument("terminology_file", help="Path to the terminology file (each line a Python literals)")
    parser.add_argument("source_lang_code", help="Source language code to be inserted into the origlang attribute.")
    parser.add_argument("set_id", help="Set ID to be inserted into the setid attribute.")
    parser.add_argument("output_file", help="Path to the output XML file.")
    args = parser.parse_args()

    generate_output(args.input_file, args.terminology_file, args.source_lang_code, args.set_id, args.output_file)


if __name__ == "__main__":
    main()

