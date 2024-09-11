from langcodes import *

### Evaluation

rule evaluate:
    message: "Evaluating a model"
    log: f'{config["log_dir"]}/eval_{{model}}_{{dataset}}_{{langpair}}.log'
    conda: "../envs/base.yml"
    threads: config["gpus_num"] * 2
    resources: gpu=config["gpus_num"]
    priority: 50
    wildcard_constraints:
        model="[\w-]+"
    input:
        ancient(config["decoder"]),
        data_src=expand(f'{config["eval_data_dir"]}/{{dataset}}.source.gz', dataset=config["eval_datasets"], langpair=config["langpairs"]),
        data_trg=expand(f'{config["eval_data_dir"]}/{{dataset}}.target.gz', dataset=config["eval_datasets"], langpair=config["langpairs"]),
        models=lambda wildcards: f'{config["models_dir"]}/{wildcards.model}/{config["best_model"]}'
                                    if wildcards.model != 'teacher-ensemble'
                                    else [f'{config["final_teacher_dir"]}0-{ens}/{config["best_model"]}' for ens in config["ensemble"]]
    output:
        report(f'{config["eval_res_dir"]}/{{model}}/{{langpair}}/{{dataset}}.metrics',
            category='evaluation', subcategory='{model}', caption='reports/evaluation.rst')
    params:
        dataset_prefix=f'{config["eval_data_dir"]}/{{dataset}}',
        res_prefix=f'{config["eval_res_dir"]}/{{model}}/{{langpair}}/{{dataset}}',
        src=lambda wildcards: wildcards.langpair.split('-')[0] if wildcards.model != "backward" else wildcards.langpair.split('-')[1],
        trg=lambda wildcards: wildcards.langpair.split('-')[1] if wildcards.model != "backward" else wildcards.langpair.split('-')[0],
        trg_three_letter=lambda wildcards: Language.get(wildcards.langpair.split('-')[1]).to_alpha3() if wildcards.model != "backward" else Language.get(wildcards.langpair.split('-')[0]).to_alpha3(),
        o2m=lambda wildcards: (
            config["o2m_teacher"] if "teacher" in wildcards.model
            else (config["o2m_backward"] if "backward" in wildcards.model 
                  else config["o2m_student"] if "student" in wildcards.model else "False")
        ),
        decoder_config=lambda wildcards: f'{config["models_dir"]}/{wildcards.model}/{config["best_model"]}.decoder.yml'
                            if wildcards.model != 'teacher-ensemble'
                            else f'{config["final_teacher_dir"]}0-0/{config["best_model"]}.decoder.yml'
    shell: '''bash pipeline/eval/eval-gpu.sh  "{params.src}" "{params.trg}" "{params.res_prefix}" "{params.dataset_prefix}" \
             {params.trg_three_letter} "{params.decoder_config}" {wildcards.model} {params.o2m} {input.models} >> {log} 2>&1'''


rule eval_quantized:
    message: "Evaluating quantized student model"
    log: f'{config["log_dir"]}/eval_quantized_{{dataset}}_{{langpair}}.log'
    conda: "../envs/base.yml"
    threads: 1
    priority: 50
    input:
        ancient(config["bmt_decoder"]),
        data_src=expand(f'{config["eval_data_dir"]}/{{dataset}}.source.gz', dataset=config["eval_datasets"], langpair=config["langpairs"]),
        data_trg=expand(f'{config["eval_data_dir"]}/{{dataset}}.target.gz', dataset=config["eval_datasets"], langpair=config["langpairs"]),
        model=config["quantized_model"],
        shortlist=config["shortlist"],
        vocab=config["vocab"]
    output:
        report(f'{config["eval_speed_dir"]}/{{langpair}}/{{dataset}}.metrics', category='evaluation',
            subcategory='quantized', caption='reports/evaluation.rst')
    params:
        dataset_prefix=f'{config["eval_data_dir"]}/{{dataset}}',
        res_prefix=f'{config["eval_speed_dir"]}/{{langpair}}/{{dataset}}',
        trg_lng=lambda wildcards: wildcards.langpair.split('-')[1],
        trg_three_letter=lambda wildcards: Language.get(wildcards.langpair.split('-')[1]).to_alpha3(), 
        decoder_config='../../quantize/decoder.yml',
        o2m=config["o2m_student"]
    shell: '''bash pipeline/eval/eval-quantized.sh "{wildcards.langpair}" "{input.model}" "{input.shortlist}" "{params.dataset_prefix}" \
            "{input.vocab}" "{params.res_prefix}" "{params.decoder_config}" "{params.trg_three_letter}" {params.o2m} >> {log} 2>&1'''
 	