from huggingface_hub import HfApi
import subprocess
import langcodes
import yaml
import os
import time
import sys

api = HfApi()
bicleaner_ai_models = [x.id for x in api.list_models(author="bitextor") if "bicleaner-ai" in x.id]

#this allows you to specify the model from which to start. Save time, since running
#snakemake for all lang pairs is a bit slow, even if the files have been generated
start_from = sys.argv[1]
for model in bicleaner_ai_models:
    if start_from is not None:
        if model != start_from:
            print(f"skipping {model}")
            continue
        else:
            start_from = None
    name_split = model.split('-')
    source_lang_2 = name_split[-2]
    target_lang_2 = name_split[-1]
    # some of the bicleaner-ai models already have three-letter codes, e.g. hbs
    if len(source_lang_2) != 3:
        source_lang_3 = langcodes.Language.get(source_lang_2).to_alpha3()
    else:
        source_lang_3 = source_lang_2
    if len(target_lang_2) != 3:
        #exception for norwegian, tatoeba challenge has "nor" as code for both
        if target_lang_2 == "nb" or target_lang_2 == "nn":
            target_lang_3 = "nor"
        else:
            target_lang_3 = langcodes.Language.get(target_lang_2).to_alpha3()
    else:
        target_lang_3 = target_lang_2

    print(f"Processing with model {model}")
    with open('./configs/bicleaner_scoring/config.bicleaner.yml', 'r') as template, open(f'./configs/bicleaner_scoring/config.bicleaner.{source_lang_2}-{target_lang_2}.yml', 'w') as config_file:
        config = yaml.safe_load(template)
        config["experiment"]["src"] = source_lang_2
        config["experiment"]["trg"] = target_lang_2
        config["experiment"]["src_three_letter"] = source_lang_3
        config["experiment"]["trg_three_letter"] = target_lang_3
        yaml.dump(config,config_file)
    try:
        score_file = os.path.abspath(f"../data/data/{source_lang_2}-{target_lang_2}/tatoeba-bicleaner/biclean/corpus/tc_Tatoeba-Challenge-v2023-09-26.scored.gz")
        result = subprocess.run(f"snakemake --conda-base-path ../bin --use-singularity --use-conda --configfile configs/bicleaner_scoring/config.bicleaner.{source_lang_2}-{target_lang_2}.yml --profile profiles/slurm-lumi-biclean {score_file}", capture_output=True, shell=True)
        time.sleep(5) #wait for snakemake lock to disappear
        print(result.stderr)
        print(result.stdout)
        if not os.path.exists(score_file):
            print(f"The processing should have produced the score file {score_file}, but it does not exist, exiting")
            break
    except Exception as e:
        print(str(e))
        break
