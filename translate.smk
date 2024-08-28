wildcard_constraints:
    src="\w{2,3}",
    trg="\w{2,3}",
    train_vocab="train_joint_spm_vocab[^/]+",
    train_model="train_model[^/]+",

gpus_num=config["gpus-num"]

checkpoint split_corpus:
    message: "Splitting the corpus to translate"
    log: "{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/{train_model}/translate/split_corpus.log"
    conda: "envs/base.yml"
    threads: 1
    input:
        train_source="{project_name}/{src}-{trg}/{preprocessing}/train.{src}.gz",
        train_target="{project_name}/{src}-{trg}/{preprocessing}/train.{trg}.gz"
    output: 
        directory("{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/{train_model}/translate/corpus")
    shell: '''bash pipeline/translate/split-corpus.sh \
        {input.corpus_src} {input.corpus_trg} {output} {split_length} >> {log} 2>&1'''

rule translate_corpus:
    message: "Translating corpus with teacher"
    log: "{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/{train_model}/translate/corpus/translate_{part}.log"
    conda: "envs/base.yml"
    threads: gpus_num*2
    resources: gpu=gpus_num
    input:
        ancient(decoder),
        file="{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/{train_model}/translate/corpus/file.{part}",
        vocab="{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/vocab.spm",
    	model=f'{{project_name}}/{{src}}-{{trg}}/{{preprocessing}}/{{train_vocab}}/train_model_{{model_type}}-{{training_type}}/final.npz.best-{config["best-model-metric"]}.npz'
    output: file="{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/{train_model}/translate/corpus/file.{part}.nbest"
    params: args=get_args('decoding-teacher')
    shell: '''bash pipeline/translate/translate-nbest.sh \
                "{input.file}" "{output.file}" "{input.vocab}" {input.teacher_models} {params.args} >> {log} 2>&1'''

rule extract_best:
    message: "Extracting best translations for the corpus"
    log: "{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/{train_model}/translate/corpus/extract_best_{part}.log"
    conda: "envs/base.yml"
    threads: 1
    input: 
        nbest="{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/{train_model}/translate/corpus/file.{part}.nbest",
        ref="{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/{train_model}/translate/corpus/file.{part}.ref"
    output: "{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/{train_model}/translate/corpus/file.{{part}}.nbest.out"
    shell: 'python pipeline/translate/bestbleu.py -i {input.nbest} -r {input.ref} -m bleu -o {output} >> {log} 2>&1'

model_indices = list(range(len(opusmt_teacher))) if opusmt_teacher else [0]

rule collect_corpus:
    message: "Collecting translated corpus"
    log: f"{log_dir}/collect_corpus_{{model_index}}.log"
    conda: "envs/base.yml"
    threads: 4
    input: lambda wildcards: expand(f"{translated}/corpus/file.{{part}}.nbest.{wildcards.model_index}.out", part=find_parts(wildcards, checkpoints.split_corpus))
    output: trg_corpus=f'{translated}/corpus.{{model_index}}.{trg}.gz'
    params: src_corpus=clean_corpus_src
    shell: 'bash pipeline/translate/collect.sh {translated}/corpus {output} {params.src_corpus} {wildcards.model_index} >> {log} 2>&1'

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

