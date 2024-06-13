import argparse
import os
import torch

# Make sure we have a GPU
print(torch.cuda.is_available())
print(torch.cuda.device_count())
#print(torch.cuda.get_device_name(0))

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
    
    from transformers import pipeline # It is here since we first need to change the cache directory
    
    # Initialize the translation pipeline with cache_dir
    pipe = pipeline(
        task=args.task,
        model=args.modelname,
        num_beams=8,
        num_return_sequences=8,
        device_map="auto",
        batch_size=32, max_length=150
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
            batch_size=32,
            src_lang=src_lang,
            tgt_lang=trg_lang
        )

    # Read the input text
    with open(args.filein, 'r', encoding='utf-8') as infile:
        text = infile.readlines()
    
    if args.prompt:
        # Modify the input text based on the prompt
        with open(args.filein, 'r', encoding='utf-8') as infile:
            text = [args.prompt.replace('<sourcetext>', line.strip()) for line in infile]
            # Show an example of how the prompt is added to the input text
            print(f"Added prompt like this:\n{text[0]}")
    else:
        with open(args.filein, 'r', encoding='utf-8') as infile:
            text = infile.readlines()

    # Perform the translation
    translations = pipe(text)
    key = list(translations[0][0].keys())[0] # Depending on the task, this may be either "translation_text" or "generated_text"

    # Write the results to the output file
    with open(args.fileout, 'w', encoding='utf-8') as outfile:
        for i, sentence in enumerate(translations):
            for translation in sentence:
                outfile.write(f"{i} ||| {translation[key]}\n")

if __name__ == "__main__":
    main()
