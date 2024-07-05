from langcodes import *

rule translate_corpus_hf:
    message: "Translating corpus with Hugging Face teacher"
    log: f"{config['log_dir']}/translate_corpus/{{langpair}}/{{part}}.{{model_index}}.log"
    conda: "../envs/hf.yml"
    threads: config["gpus_num"] * 2
    resources: gpu=config["gpus_num"]
    input:
        file=config["teacher_source_file"]
    output: file=config["teacher_target_file"]
    params: src_three_letter=lambda wildcards: Language.get(wildcards.langpair.split('-')[0]).to_alpha3(),
            trg_three_letter=lambda wildcards: Language.get(wildcards.langpair.split('-')[1]).to_alpha3(),
            prompt=config["prompt"],
            model_dir=config["final_teacher_dir"],
            teacher=config["hf_teacher"],
            task=config["task"]
    # Hacky way to deal with optional prompt
    shell: '''
        PROMPT_ARG=""
        if [ ! -z "{params.prompt}" ]; then
            PROMPT_ARG="--prompt '{params.prompt}'"
        fi

        python pipeline/translate/translate_hf.py \
            "{input.file}" "{output.file}" "{params.teacher}" "{params.model_dir}" "{params.src_three_letter}" "{params.trg_three_letter}" "{params.task}" $PROMPT_ARG >> {log} 2>&1
    '''