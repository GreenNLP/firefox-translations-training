import argparse
import sentencepiece as spm
import ctranslate2
import sys
import time

def translate_file(model_dir, input_file, sp_model_path, threads, batch_size, beam_size, num_hypotheses, output_file, compute_type):
    # Load the CTranslate2 model and SentencePiece model
    translator = ctranslate2.Translator(model_dir, device="auto", inter_threads=threads, compute_type=compute_type)
    sp = spm.SentencePieceProcessor(model_file=sp_model_path)
    # Open the input file for reading
    with open(input_file, 'r', encoding="utf-8") as f:
        # Segment the input lines using SentencePiece
        source = map(sp.encode_as_pieces, f)
        # Use translate_iterable to translate the lines incrementally
        translations = translator.translate_iterable(
            source, batch_type="tokens", beam_size=beam_size, max_batch_size=batch_size, num_hypotheses=num_hypotheses, disable_unk=True)

        # Decode the translations back into text and print them
        translation_count = 0
        if output_file:
            with open(output_file,'wt',encoding="utf-8") as output:
                for translation in translations:
                    translation_count += 1
                    decoded_hypotheses = sp.decode(translation.hypotheses[0:num_hypotheses])
                    for hyp in decoded_hypotheses:
                        output.write(hyp+"\n")
        else:
            for translation in translations:
                translation_count += 1
                decoded_hypotheses = sp.decode(translation.hypotheses[0:num_hypotheses])
                for hyp in decoded_hypotheses:
                    sys.stdout.write(hyp+"\n")
    return translation_count
        
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Translate text using a CTranslate2 model and SentencePiece.")
    parser.add_argument("--model_directory", help="Path to the CTranslate2 model directory")
    parser.add_argument("--input_file", help="Path to the input file containing text to translate")
    parser.add_argument("--sentencepiece_model", help="Path to the SentencePiece model file")
    parser.add_argument("--threads", type=int, help="Number of threads to use")
    parser.add_argument("--batch_size", type=int, default=32, help="Batch size")
    parser.add_argument("--beam_size", type=int, default=6, help="Beam size")
    parser.add_argument("--num_hypotheses", type=int, default=1, help="n-best list size")
    parser.add_argument("--output_file", type=str, default=None, help="Output file, default is stdout")
    parser.add_argument("--compute_type", type=str, default="default", help="Quantization to use on model loading")

    args = parser.parse_args()
    t = time.process_time()
    translation_count = translate_file(args.model_directory, args.input_file, args.sentencepiece_model, args.threads, args.batch_size, args.beam_size, args.num_hypotheses, args.output_file, args.compute_type)
    sys.stderr.write(f"translated {translation_count} sentences in {int(time.process_time())} seconds\n")
