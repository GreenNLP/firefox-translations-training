import argparse

def process_files(source_file, nbest_file, reference_file):
    with open(source_file, 'r', encoding='utf-8') as src, \
         open(nbest_file, 'r', encoding='utf-8') as nbest, \
         open(reference_file, 'r', encoding='utf-8') as ref:

        # Open output files for fuzzy and non-fuzzy sentences
        with open(reference_file+".fuzzies", 'w', encoding='utf-8') as fuzzies_ref, \
             open(nbest_file+".fuzzies", 'w', encoding='utf-8') as fuzzies_nbest, \
             open(source_file+".fuzzies", 'w', encoding='utf-8') as fuzzies_src, \
             open(reference_file+".nonfuzzies", 'w', encoding='utf-8') as nonfuzzies_ref, \
             open(nbest_file+".nonfuzzies", 'w', encoding='utf-8') as nonfuzzies_nbest, \
             open(source_file+".nonfuzzies", 'w', encoding='utf-8') as nonfuzzies_src:

            # Initialize counters for new indices
            fuzzy_idx = 0
            nonfuzzy_idx = 0

            # Iterate through each line of the source file and corresponding reference
            for src_line, ref_line in zip(src, ref):
                src_line = src_line.strip()
                ref_line = ref_line.strip()

                # Check for 'FUZZY_BREAK' in the source line
                if 'FUZZY_BREAK' in src_line:
                    # Write the part before 'FUZZY_BREAK' to fuzzies.ref
                    fuzzies_ref.write(src_line.split('FUZZY_BREAK')[0].strip() + '\n')
                    fuzzies_src.write(src_line + '\n')
                    for _ in range(8):
                        nbest_line = nbest.readline().strip()
                        fields = nbest_line.split('|||')
                        fields[0] = f"{fuzzy_idx} "  # Update the index to be consecutive
                        fuzzies_nbest.write('|||'.join(fields).strip() + '\n')
                    fuzzy_idx += 1  # Increment the fuzzy index

                else:
                    # Write the full line to nonfuzzies.ref
                    nonfuzzies_ref.write(ref_line + '\n')
                    nonfuzzies_src.write(src_line + '\n')

                    # Write the corresponding 8 translations to nonfuzzies.nbest
                    for _ in range(8):
                        nbest_line = nbest.readline().strip()
                        fields = nbest_line.split('|||')
                        fields[0] = f"{nonfuzzy_idx} "  # Update the index to be consecutive
                        nonfuzzies_nbest.write('|||'.join(fields).strip() + '\n')
                    nonfuzzy_idx += 1  # Increment the non-fuzzy index

if __name__ == "__main__":
    # Setup argparse to handle the input files as arguments
    parser = argparse.ArgumentParser(description='Process source, nbest, and reference files.')
    parser.add_argument('--source_file', type=str, required=True, help='Path to the source file.')
    parser.add_argument('--nbest_file', type=str, required=True, help='Path to the nbest file containing translations.')
    parser.add_argument('--reference_file', type=str, required=True, help='Path to the reference file.')

    # Parse arguments
    args = parser.parse_args()

    # Process files
    process_files(args.source_file, args.nbest_file, args.reference_file)

