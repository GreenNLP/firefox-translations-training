import argparse
import os
from transformers import pipeline
import time
import torch

def parse_args():
    parser = argparse.ArgumentParser(description="Translate text using Hugging Face pipeline.")
    parser.add_argument('filein', type=str, help='Input file name')
    parser.add_argument('fileout', type=str, help='Output file name')
    parser.add_argument('modelname', type=str, help='Model name')
    parser.add_argument('modeldir', type=str, help='Model directory')
    parser.add_argument('src', type=str, help='Source language prefix')
    parser.add_argument('trg', type=str, help='Target language prefix')
    parser.add_argument('task', type=str, help='Translation task')
    parser.add_argument('--prompt', type=str, default=None, help='Optional prompt for the translation')
    return parser.parse_args()

def main():
    args = parse_args()
    os.environ['HF_HOME'] = args.modeldir

    print(f"Translating {args.filein} from {args.src} to {args.trg} with {args.modelname}...")

    print("PyTorch version:", torch.__version__)
    print("CUDA available:", torch.cuda.is_available())
    print("GPUs available:", torch.cuda.device_count())

    # Initialize the translation pipeline with cache_dir
    pipe = pipeline(
        task=args.task,
        model=args.modelname,
        num_beams=8,
        num_return_sequences=8,
        device_map="auto",
        max_length=150
    )

    if "nllb" in args.modelname:
        print("It is a NLLB model, so we need to add source and target languages.")
        # List of available languages for nllb
        available_languages = pipe.tokenizer.additional_special_tokens
        src_lang = next((code for code in available_languages if code.startswith(args.src)), None)
        trg_lang = next((code for code in available_languages if code.startswith(args.trg)), None)
        # Check if the full language code was found
        if src_lang is None or trg_lang is None:
            raise ValueError("The model does not include all your languages")
        else:
            print(f"Source language found: {src_lang}")
            print(f"Target language found: {trg_lang}")
            
        pipe = pipeline(
            task=args.task,
            model=args.modelname,
            num_beams=8,
            num_return_sequences=8,
            device_map="auto",
            src_lang=src_lang,
            tgt_lang=trg_lang,
            max_length=150
        )

    # Read the input text
    with open(args.filein, 'r', encoding='utf-8') as infile:
        text = infile.readlines()
    
    if args.prompt:
        # Modify the input text based on the prompt
        text = [args.prompt.replace('<sourcetext>', line.strip()) for line in text]
        # Show an example of how the prompt is added to the input text
        print(f"Added prompt like this:\n{text[0]}")

    # Prepare for batch processing
    batch_size = 32

    # Open the output file in append mode
    with open(args.fileout, 'a', encoding='utf-8') as outfile:
        start_time = time.time()  # Start time
        # Perform the translation with progress print statements
        for i in range(0, len(text), batch_size):
            batch = text[i:i+batch_size]
            translated_batch = pipe(batch)

            key = list(translated_batch[0][0].keys())[0] # Depending on the task, this may be either "translation_text" or "generated_text"
            
            # Write each translated sentence to the output file incrementally
            for sentence in translated_batch:
                for translation in sentence:
                    outfile.write(f"{i} ||| {translation[key]}\n")

            # Print progress every 50 sentences
            if i % 50 == 0:
                print(f"Translated {i} sentences...")
        end_time = time.time()  # End time
        total_time = end_time - start_time
        translations_per_second = len(text) / total_time if total_time > 0 else float('inf')

    # Final progress print
    print(f"Translation complete. Translating {len(text)} sentences took {total_time} seconds.")
    print(f"{translations_per_second:.2f} translations/second")

if __name__ == "__main__":
    main()