import argparse
import os
import sentencepiece as spm
import yaml


def find_symbols_with_lowest_scores(source_sp, target_sp, vocab):
    #three criteria for symbols to replace:
    #1. uncommon in source spm
    #2. do not exist in target spm
    #3. do exist in vocab (theoretically they all exist, but there are some unicode
    #conversion issues that this approach avoids)
    source_scores = [(symbol, source_sp.get_score(symbol)) for symbol in range(0,source_sp.vocab_size())]
    worst_to_best_source = [source_sp.id_to_piece(x[0]) for x in sorted(source_scores, key=lambda y: y[1])]
    target_symbols = [target_sp.id_to_piece(symbol) for symbol in range(0,target_sp.vocab_size())]

    special_symbols = []
    for source_symbol in worst_to_best_source:
        if source_symbol in target_symbols:
            continue
        elif source_symbol in vocab:
            special_symbols.append(source_symbol)
            if len(special_symbols) == 3:
                break

    return special_symbols

def replace_symbols_in_yaml_vocab(vocab, new_yaml_file, symbols_to_replace):
    new_vocab = vocab.copy()
    special_symbols = ['augmentsymbol0', 'augmentsymbol1', 'augmentsymbol2']
    for symbol in symbols_to_replace:
        if symbol in new_vocab:
            new_vocab[special_symbols.pop()] = new_vocab.pop(symbol)
            if len(special_symbols) == 0:
                break
    with open(new_yaml_file, 'w') as f:
        yaml.dump(new_vocab, f, encoding='utf-8', allow_unicode=True)

def main():
    parser = argparse.ArgumentParser(description='Process SentencePiece model and Marian yaml vocabulary')
    parser.add_argument('--source_spm_model', type=str, help='Source SentencePiece model file')
    parser.add_argument('--target_spm_model', type=str, help='Target SentencePiece model file')
    parser.add_argument('--yaml_vocab', type=str, help='Marian yaml vocabulary file')
    args = parser.parse_args()

    # The vocabs are occasionally corrupt, safe_load will break on unquoted <<, so fix that
    fixed_yaml_path = f"{args.yaml_vocab}.fixed"
    with open(args.yaml_vocab,'r') as orig_vocab, open(fixed_yaml_path,'w') as fixed_yaml:
        for line in orig_vocab:
            if line.startswith("<<:"):
                line = line.replace('<<:','"<<":')
            fixed_yaml.write(line)

    with open(fixed_yaml_path, 'r') as f:
        vocab = yaml.safe_load(f)

    source_sp = spm.SentencePieceProcessor(args.source_spm_model)
    target_sp = spm.SentencePieceProcessor(args.target_spm_model)

   
    source_symbols_with_lowest_scores = find_symbols_with_lowest_scores(source_sp, target_sp, vocab)
    new_yaml_file = os.path.splitext(args.yaml_vocab)[0] + '_term.yaml'
    replace_symbols_in_yaml_vocab(vocab, new_yaml_file, source_symbols_with_lowest_scores)

    os.rename(args.yaml_vocab, f"{args.yaml_vocab}.bak")
    os.rename(new_yaml_file, f"{args.yaml_vocab}")
    

if __name__ == "__main__":
    main()

