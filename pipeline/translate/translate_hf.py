import argparse
import os
import torch
import time
import ast
from accelerate import Accelerator, DataLoaderConfiguration
from torch.utils.data import DataLoader, Dataset
from transformers import AutoTokenizer
import importlib

torch.cuda.empty_cache()  # Clear unused memory

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

def convert_simple_dict(d):
    """Convert numeric strings to integers or floats in a flat dictionary."""
    return {key: ast.literal_eval(value) if isinstance(value, str) and value.isdigit() else value for key, value in d.items()}

class TokenizedDataset(Dataset):
    def __init__(self, tokenized_inputs):
        self.tokenized_inputs = tokenized_inputs

    def __len__(self):
        return len(self.tokenized_inputs['input_ids'])

    def __getitem__(self, idx):
        return {key: val[idx] for key, val in self.tokenized_inputs.items()}

def main():
    #os.environ['HF_HOME'] = args.modeldir
    args = parse_args()

    # Create a DataLoaderConfiguration object
    dataloader_config = DataLoaderConfiguration(split_batches=True)

    # Pass the config to the Accelerator
    accelerator = Accelerator(device_placement=True, dataloader_config=dataloader_config)

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

    model = model_class.from_pretrained(model_name, trust_remote_code=True, device_map='auto')
    model = accelerator.prepare(model)  # Prepare model for distributed inference

    # Mapping target languages
    src_lang = lang_tags.get(args.src, None)
    tgt_lang = lang_tags.get(args.trg, None)

    if args.langinfo in ["True","true","1"]:
        tokenizer = AutoTokenizer.from_pretrained(model_name, trust_remote_code=True, src_lang=src_lang, tgt_lang=tgt_lang, use_fast=True)
    else:
        tokenizer = AutoTokenizer.from_pretrained(model_name, trust_remote_code=True, use_fast=True)

    num_return_sequences=8

    if args.config == "default":
        config=dict()
    else:
        config=convert_simple_dict(ast.literal_eval(args.config))

    print("Tokenizing...")

    # Read the input text
    with open(args.filein, 'r', encoding='utf-8') as infile:
        text = infile.readlines()
    
    # Format sentences with prompt
    formatted_text = [prompt.format(src_lang=src_lang, tgt_lang=tgt_lang, source=t) for t in text]

    # Tokenize all the inputs at once
    tokenized_inputs = tokenizer(formatted_text, return_tensors='pt', padding=True).to(accelerator.device)

    # Prepare dataset and dataloader
    dataset = TokenizedDataset(tokenized_inputs)
    batch_size = 32
    dataloader = DataLoader(dataset, batch_size=batch_size, shuffle=False)
   
    print("Starting translations...")

    # Accumulate multiple sentences in memory and write them to the file in larger batches
    buffer_size = 1000000
    buffer = []

    with open(args.fileout, 'w', encoding='utf-8') as outfile:
        start_time = time.time()
        sentence_counter = 0

        for batch in accelerator.prepare(dataloader):
            
            # Generate output
            translated_batch = model.generate(
                **batch,
                num_return_sequences=num_return_sequences,
                num_beams=num_return_sequences,
                **config,
            )

            # Decode the output
            translated_batch = tokenizer.batch_decode(translated_batch, skip_special_tokens=True)

            # Write each translated sentence to the buffer
            for i, sentence in enumerate(translated_batch):
                curr_prompt = prompt.format(src_lang=src_lang, tgt_lang=tgt_lang, source=text[i])
                sentence = sentence.replace(curr_prompt, "")

                # Add to buffer
                buffer.append(f"{sentence_counter} ||| {sentence}\n")

                # Increment sentence counter every num_return_sequences sentences
                if (i + 1) % num_return_sequences == 0:
                    sentence_counter += 1

                # When buffer is full, write it to file and clear the buffer
                if len(buffer) >= buffer_size:
                    outfile.writelines(buffer)  # Write buffer to file
                    buffer = []  # Clear the buffer

            # Print progress every 50 sentences
            if sentence_counter % 50 == 0:
                print(f"Translated {sentence_counter} sentences...")

        # If there are any remaining sentences in the buffer, flush them to the file
        if buffer:
            outfile.writelines(buffer)

        end_time = time.time()
        total_time = end_time - start_time
        translations_per_second = len(text) / total_time if total_time > 0 else float('inf')

    # Final progress print
    print(f"Translation complete. Translating {len(text)} sentences took {total_time:.2f} seconds.")
    print(f"{translations_per_second:.2f} translations/second")

if __name__ == "__main__":
    main()
