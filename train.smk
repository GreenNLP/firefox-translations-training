# set common variables based on config values

#The cleaned and potentially augmented data that will be used to train the model
train_src=f'{config["trainset-dir"]}/{{trainset}}/output/train/corpus.{{src}}-{{trg}}.{{src}}.gz'
train_trg=f'{config["trainset-dir"]}/{{trainset}}/output/train/corpus.{{src}}-{{trg}}.{{trg}}.gz'

#The cleaned and potentially augmented dev data
dev_src=f'{config["devset-dir"]}/devset.{{src}}-{{trg}}.{{src}}.gz'
dev_trg=f'{config["devset-dir"]}/devset.{{src}}-{{trg}}.{{trg}}.gz'

vocab=f'{config["vocab-dir"]}/vocab.{{trainset}}.{{src}}-{{trg}}.{{spm_vocab_size}}.spm'
gpus_num=config["gpus-num"]

rule train_model:
    message: "Training a model"
    log: f"{{src}}-{{trg}}/{{trainset}}-{{spm_vocab_size}}-{{model_type}}-{{training_type}}-{{kd_type}}-{{ens}}.log"
    conda: "envs/base.yml"
    threads: gpus_num*3
    resources: gpu=gpus_num,mem_mb=64000
    wildcard_constraints:
       ens="\d+"
    input:
        dev_src=dev_src,
        dev_trg=dev_trg,
        train_src=train_src,
        train_trg=train_trg,
        marian=ancient(config["marian"]),
        vocab=vocab
    output: 
        model=f'{{src}}-{{trg}}/{{trainset}}-{{spm_vocab_size}}-{{model_type}}-{{training_type}}-{{kd_type}}-{{ens}}/{config["best-model"]}'
    params:
        args=config["training-teacher-args"]
    shell: f'''bash pipeline/train/train.sh \
                {{wildcards.kd_type}} {{wildcards.training_type}} {{wildcards.src}} {{wildcards.trg}} "{{input.train_src}}" "{{input.train_trg}}" "{{input.dev_src}}" "{{input.dev_trg}}" "{{output.model}}" "{{input.vocab}}" "{config["best-model-metric"]}" {{params.args}} >> {{log}} 2>&1'''

