wildcard_constraints:
    src="\w{2,3}",
    trg="\w{2,3}",
    train_vocab="train_joint_spm_vocab[^/]+"

gpus_num=config["gpus-num"]

rule train_model:
    message: "Training a model"
    log: "{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/train_model_{model_type}-{training_type}/train_model.log"
    conda: "envs/base.yml"
    threads: gpus_num*3
    resources: gpu=gpus_num,mem_mb=64000
    input:
        dev_source="{project_name}/{src}-{trg}/{preprocessing}/dev.{src}.gz",
        dev_target="{project_name}/{src}-{trg}/{preprocessing}/dev.{trg}.gz",
        train_source="{project_name}/{src}-{trg}/{preprocessing}/train.{src}.gz",
        train_target="{project_name}/{src}-{trg}/{preprocessing}/train.{trg}.gz",
        marian=ancient(config["marian"]),
        vocab="{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/vocab.spm",
    output: 
    	model=f'{{project_name}}/{{src}}-{{trg}}/{{preprocessing}}/{{train_vocab}}/train_model_{{model_type}}-{{training_type}}/final.npz.best-{config["best-model-metric"]}.npz'
    params:
        args=config["training-teacher-args"]
    shell: f'''bash pipeline/train/train.sh \
                {{wildcards.model_type}} {{wildcards.training_type}} {{wildcards.src}} {{wildcards.trg}} "{{input.train_source}}" "{{input.train_target}}" "{{input.dev_source}}" "{{input.dev_target}}" "{{output.model}}" "{{input.vocab}}" "{config["best-model-metric"]}" {{params.args}} >> {{log}} 2>&1'''

