import argparse
import sentencepiece as spm
import ctranslate2

def load_sentencepiece_model(sp_model_path):
    sp = spm.SentencePieceProcessor()
    sp.load(sp_model_path)
    return sp

def translate_file(model_dir, input_file, sp_model_path, threads):
    # Load the CTranslate2 model and SentencePiece model
    translator = ctranslate2.Translator(model_dir, inter_threads=threads)
    sp = load_sentencepiece_model(sp_model_path)
    
    # Open the input file for reading
    with open(input_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    # Segment the input lines using SentencePiece
    segmented_lines = [sp.encode(line.strip(), out_type=str) for line in lines]

    # Use translate_iterable to translate the lines incrementally
    translations = translator.translate_iterable(segmented_lines, beam_size=5)

    # Decode the translations back into text and print them
    for translation in translations:
        translated_sentence = sp.decode(translation.hypotheses[0])
        print(translated_sentence)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Translate text using a CTranslate2 model and SentencePiece.")
    parser.add_argument("--model_directory", help="Path to the CTranslate2 model directory")
    parser.add_argument("--input_file", help="Path to the input file containing text to translate")
    parser.add_argument("--sentencepiece_model", help="Path to the SentencePiece model file")
    parser.add_argument("--threads", help="Number of threads to use")

    args = parser.parse_args()
    
    translate_file(args.model_directory, args.input_file, args.sentencepiece_model)

