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
    params: src=lambda wildcards: wildcards.langpair.split('-')[0],
            trg=lambda wildcards: wildcards.langpair.split('-')[1],
            model_dir=config["final_teacher_dir"],
            teacher=config["hf_teacher"],
            modelclass=config["modelclass"],
            langinfo=config["langinfo"],
            prompt={config["prompt"]},
            langtags=config["langtags"],
            decoder_config=config["decoder_config"]

    shell: '''
        python pipeline/translate/translate_hf.py \
            "{input.file}" "{output.file}" "{params.teacher}" "{params.model_dir}" "{params.src}" "{params.trg}" \
            "{params.modelclass}" "{params.langinfo}" "{params.prompt}" "{params.langtags}" "{params.decoder_config}" >> {log} 2>&1
        '''