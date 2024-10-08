wildcard_constraints:
    src="\w{2,3}",
    trg="\w{2,3}",
    train_vocab="train_joint_spm_vocab[^/]+",
    training_type="[^/]+",
    model_type="[^/_]+"

gpus_num=config["gpus-num"]

rule train_model:
    message: "Training a model"
    log: "{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/train_model_{index_type}-{model_type}-{training_type}_train_model.log"
    conda: "envs/base.yml"
    envmodules:
        "LUMI/22.08",
        "partition/G",
        "rocm/5.3.3"
    threads: gpus_num*3
    resources: gpu=gpus_num,mem_mb=64000
    input:
        dev_source="{project_name}/{src}-{trg}/{preprocessing}/{index_type}-dev.{src}.gz",
        dev_target="{project_name}/{src}-{trg}/{preprocessing}/{index_type}-dev.{trg}.gz",
        train_source="{project_name}/{src}-{trg}/{preprocessing}/{index_type}-train.{src}.gz",
        train_target="{project_name}/{src}-{trg}/{preprocessing}/{index_type}-train.{trg}.gz",
        marian=ancient(config["marian"]),
        vocab="{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/vocab.spm",
    output: 
    	model=f'{{project_name}}/{{src}}-{{trg}}/{{preprocessing}}/{{train_vocab}}/train_model_{{index_type}}-{{model_type}}-{{training_type}}/final.model.npz.best-{config["best-model-metric"]}.npz'
    params:
        args=config["training-teacher-args"]
    shell: f'''bash pipeline/train/train.sh \
                {{wildcards.model_type}} {{wildcards.training_type}} {{wildcards.src}} {{wildcards.trg}} "{{input.train_source}}" "{{input.train_target}}" "{{input.dev_source}}" "{{input.dev_target}}" "{{output.model}}" "{{input.vocab}}" "{config["best-model-metric"]}" {{params.args}} >> {{log}} 2>&1'''


use rule train_model as train_student_model with:
    message: "Training a student model"
    log: "{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/{postprocessing}/train_model_{model_type}-{training_type}/train_model.log"
    input:
        dev_source="{project_name}/{src}-{trg}/{preprocessing}/dev.{src}.gz",
        dev_target="{project_name}/{src}-{trg}/{preprocessing}/dev.{trg}.gz",
        train_source="{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/{postprocessing}/train.{src}.gz",
        train_target="{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/{postprocessing}/train.{trg}.gz",
        marian=ancient(config["marian"]),
        vocab="{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/vocab.spm"
    output: 
    	model=f'{{project_name}}/{{src}}-{{trg}}/{{preprocessing}}/{{train_vocab}}/{{postprocessing}}/train_model_{{model_type}}-{{training_type}}/final.model.npz.best-{config["best-model-metric"]}.npz'
        

localrules: ct2_conversion

rule ct2_conversion:
    message: "Converting Marian model for ctranslate2 use"
    log: "{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/train_model_{model_type}-{training_type}/convert_model.log"
    conda: None
    container: None
    threads: 1
    input:
    	model=f'{{project_name}}/{{src}}-{{trg}}/{{preprocessing}}/{{train_vocab}}/train_model_{{model_type}}-{{training_type}}/final.model.npz.best-{config["best-model-metric"]}.npz',
        vocab="{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/vocab.spm"
    output: 
    	model='{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/train_model_{model_type}-{training_type}/ct2_conversion/model.bin'
    params:
        text_vocab="{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/vocab.vocab",
        yml_vocab="{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/train_model_{model_type}-{training_type}/conversion_vocab.yml",
        conversion_dir="{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/train_model_{model_type}-{training_type}/ct2_conversion"
    shell:
        """
            python pipeline/train/convert_vocab.py --input_vocab {params.text_vocab} --output_vocab {params.yml_vocab} >> {log} 2>&1 && \
            ct2-marian-converter --force --model_path {input.model} --vocab_paths {params.yml_vocab} {params.yml_vocab} --output_dir {params.conversion_dir} >> {log} 2>&1
        """ 

