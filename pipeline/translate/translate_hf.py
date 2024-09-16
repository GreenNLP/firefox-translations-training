import argparse
import os
import torch
import time
import ast

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

from transformers import AutoTokenizer

import importlib

def parse_args():
    parser = argparse.ArgumentParser(description="Translate text using Hugging Face pipeline.")
    parser.add_argument('filein', type=str, help='Input file name')
    parser.add_argument('fileout', type=str, help='Output file name')
    parser.add_argument('modelname', type=str, help='Model name')
    parser.add_argument('modeldir', type=str, help='Model directory')
    parser.add_argument('src', type=str, help='Source language prefix')
    parser.add_argument('trg', type=str, help='Target language prefix')
    parser.add_argument('modelclass', type=str, help='Model class string')
    parser.add_argument('langinfo',  type=str, help="Specify if source and target languages are required")
    parser.add_argument('prompt',  type=str, help="Prompt to use for decoding")
    parser.add_argument('langtags',  type=str, help="Language tag mapping specific to the model")
    parser.add_argument('config',  type=str, help="Specific configuration for decoding")
    return parser.parse_args()

def main():
    args = parse_args()
    os.environ['HF_HOME'] = args.modeldir

    print(f"Translating {args.filein} from {args.src} to {args.trg} with {args.modelname}...")

    print("PyTorch version:", torch.__version__)
    print("CUDA available:", torch.cuda.is_available())
    print("GPUs available:", torch.cuda.device_count())

    model_name=args.modelname
    prompt=args.prompt
    lang_tags=ast.literal_eval(args.langtags)

    # Split the module and class names
    module_name, class_name = args.modelclass.rsplit(".", 1)
    # Import the module
    module = importlib.import_module(module_name)
    # Get the class from the module
    model_class = getattr(module, class_name)

    model = model_class.from_pretrained(model_name, trust_remote_code=True).to(device)
    
    # Mapping target languages
    src_lang = lang_tags.get(args.src, None)
    tgt_lang = lang_tags.get(args.trg, None)

    if args.langinfo in ["True","true","1"]:

        tokenizer = AutoTokenizer.from_pretrained(model_name, trust_remote_code=True, src_lang=src_lang, tgt_lang=trg_lang)
    else:
        tokenizer = AutoTokenizer.from_pretrained(model_name, trust_remote_code=True )

    num_return_sequences=8
    if args.config == "default":
        config=dict()
    else:
        config=ast.literal_eval(args.config)

    print("Starting translations...")

    # Read the input text
    with open(args.filein, 'r', encoding='utf-8') as infile:
        text = infile.readlines()
    
    # Prepare for batch processing
    batch_size = 32

    # Open the output file in append mode
    with open(args.fileout, 'a', encoding='utf-8') as outfile:
        start_time = time.time()  # Start time
        # Perform the translation with progress print statements
        for i in range(0, len(text), batch_size):
            batch = text[i:i+batch_size]
            input_texts=[prompt.format(src_lang=src_lang, tgt_lang=tgt_lang, source=input_text) for input_text in batch]
            print("Sample source sentence after prompt formatting:\n", input_texts[0])
            inputs=tokenizer(input_texts, return_tensors="pt",padding=True).to(device)

            # Generate output
            translated_batch = model.generate(
                **inputs,
                num_return_sequences=num_return_sequences,
                num_beams=num_return_sequences,
                **config,
            )

            # Decode the output
            translated_batch = tokenizer.batch_decode(translated_batch, skip_special_tokens=True)
                
            # Write each translated sentence to the output file incrementally
            i = 0  # Initialize 'i' outside the loop
            sentence_counter = 0  # Counter to track every 8 sentences

            for sentence in translated_batch:
                # Remove prompt before writing out
                if prompt != "{source}":
                    print("source text:",batch[i])
                    print("translation:",sentence)
                    curr_prompt=prompt.format(src_lang=src_lang, tgt_lang=tgt_lang, source=batch[i])
                    print("prompt:",curr_prompt)
                    sentence=sentence.replace(curr_prompt,"")
                    print("fixed translation:",sentence)
                
                outfile.write(f"{i} ||| {sentence}\n")
                sentence_counter += 1

                # Increment 'i' every 8 sentences
                if sentence_counter % num_return_sequences == 0:
                    i += 1

            # Print progress every 50 sentences
            if sentence_counter % 50 == 0:
                print(f"Translated {sentence_counter} sentences...")

        end_time = time.time()  # End time
        total_time = end_time - start_time
        translations_per_second = len(text) / total_time if total_time > 0 else float('inf')


    # Final progress print
    print(f"Translation complete. Translating {len(text)} sentences took {total_time} seconds.")
    print(f"{translations_per_second:.2f} translations/second")

if __name__ == "__main__":
    main()