from langcodes import *

rule translate_corpus_hf:
    message: "Translating corpus with Hugging Face teacher"
    log: f"{config['log_dir']}/translate_corpus/{{langpair}}/{{part}}.{{model_index}}.log"
    conda: "../envs/hf.yml"
    threads: config["gpus_num"] * 2
    resources: gpu=config["gpus_num"]
    input:
        teacher=config["hf_teacher"],
        file=config["teacher_source_file"],
        model_dir=config["final_teacher_dir"],
        task=config["task"]
    output: file=config["teacher_target_file"]
    params: src_three_letter=lambda wildcards: Language.get(wildcards.config["langpair"].split('-')[0]).to_alpha3(),
            trg_three_letter=lambda wildcards: Language.get(wildcards.config["langpair"].split('-')[1]).to_alpha3(),
            prompt=config["prompt"]
    shell: '''
        python pipeline/translate/translate_hf.py \
            "{input.file}" "{output.file}" "{input.teacher}" "{input.model_dir}" "{params.src_three_letter}" "{params.trg_three_letter}"  "{input.task}" {params.prompt and f'--prompt {params.prompt}'} >> {log} 2>&1
    '''
