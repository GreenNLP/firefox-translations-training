import glob

wildcard_constraints:
    src="\w{2,3}",
    trg="\w{2,3}",
    train_vocab="train_joint_spm_vocab[^/]+",
    train_model="train_model[^/]+",

gpus_num=config["gpus-num"]

def find_parts(wildcards, checkpoint):
    checkpoint_output = checkpoint.get(**wildcards).output[0]
    return glob_wildcards(os.path.join(checkpoint_output,"file.{part,\d+}")).part

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
    shell: 'bash pipeline/translate/split-corpus.sh {input.train_source} {input.train_target} {output} 1000000 >> {log} 2>&1'

rule translate_corpus:
    message: "Translating corpus with teacher"
    log: "{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/{train_model}/translate/corpus/translate_{part}.log"
    conda: "envs/base.yml"
    threads: gpus_num*2
    resources: gpu=gpus_num
    input:
        ancient(config["decoder"]),
        file="{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/{train_model}/translate/corpus/file.{part}",
        vocab="{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/vocab.spm",
    	model=f'{{project_name}}/{{src}}-{{trg}}/{{preprocessing}}/{{train_vocab}}/{{train_model}}/final.model.npz.best-{config["best-model-metric"]}.npz'
    output: file="{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/{train_model}/translate/corpus/file.{part}.nbest"
    params: args=config['decoding-teacher-args']
    shell: '''bash pipeline/translate/translate-nbest.sh \
                "{input.file}" "{output.file}" "{input.vocab}" {input.model} {params.args} >> {log} 2>&1'''

rule translate_corpus_ct2:
    message: "Translating corpus with teacher using CTranslate2"
    log: "{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/{train_model}/translate/corpus/translate_ct2_{part}.log"
    conda: None
    container: None
    threads: 2
    resources: gpu=1 # the script is not set up for multiple GPUs right now
    input:
        ancient(config["decoder"]),
        file="{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/{train_model}/translate/corpus/file.{part}",
        vocab="{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/vocab.spm",
    	model='{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/{train_model}/ct2_conversion/model.bin'
    output: file="{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/{train_model}/translate/corpus/file.{part}.ct2.nbest"
    shell: '''bash pipeline/translate/translate-nbest-ct2.sh \
        "{input.file}" "{output.file}" "{input.vocab}" {input.model} >> {log} 2>&1'''

rule extract_best:
    message: "Extracting best translations for the corpus"
    log: "{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/{train_model}/translate/corpus/extract_best_{part}.log"
    conda: "envs/base.yml"
    threads: 1
    input: 
        nbest="{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/{train_model}/translate/corpus/file.{part}.nbest",
        ref="{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/{train_model}/translate/corpus/file.{part}.ref"
    output: "{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/{train_model}/translate/corpus/file.{part}.nbest.out"
    shell: 'python pipeline/translate/bestbleu.py -i {input.nbest} -r {input.ref} -m bleu -o {output} >> {log} 2>&1'

rule extract_best_copyrate:
    message: "Extracting translations with best copy rate for the corpus"
    log: "{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/{train_model}/translate/corpus/extract_best_copyrate_{part}.log"
    conda: "envs/base.yml"
    threads: 1
    input: 
        nbest="{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/{train_model}/translate/corpus/file.{part}.nbest",
        fuzzy_source_file="{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/{train_model}/translate/corpus/file.{part}",
        ref="{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/{train_model}/translate/corpus/file.{part}.ref"
    output:
        train_target="{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/{train_model}/translate/corpus/file.{part}.nbest.copyrate_out",
        train_source="{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/{train_model}/translate/corpus/file.{part}.copyrate_src"
    shell: 'pipeline/translate/bestcopyrate.sh {input.nbest} {input.ref} {input.fuzzy_source_file} {output.train_source} {output.train_target} >> {log} 2>&1'

rule collect_copyrate_corpus:
    message: "Collecting translated corpus (best copyrate)"
    log: "{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/{train_model}/translate/extract_by_copyrate/collect_corpus_copyrate.log"
    conda: "envs/base.yml"
    threads: 4
    input: lambda wildcards: expand("{{project_name}}/{{src}}-{{trg}}/{{preprocessing}}/{{train_vocab}}/{{train_model}}/translate/corpus/file.{part}.nbest.copyrate_out", part=find_parts(wildcards, checkpoints.split_corpus))
    output:
        train_source="{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/{train_model}/translate/extract_by_copyrate/train.{src}.gz",
        train_target="{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/{train_model}/translate/extract_by_copyrate/train.{trg}.gz"
    params: 
        split_dir="{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/{train_model}/translate/corpus"
    shell: 
        'bash pipeline/translate/collect_copyrate.sh {params.split_dir} {output.train_source} {output.train_target} >> {log} 2>&1'

rule collect_corpus:
    message: "Collecting translated corpus"
    log: "{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/{train_model}/translate/collect_corpus.log"
    conda: "envs/base.yml"
    threads: 4
    input: lambda wildcards: expand("{{project_name}}/{{src}}-{{trg}}/{{preprocessing}}/{{train_vocab}}/{{train_model}}/translate/corpus/file.{part}.nbest.out", part=find_parts(wildcards, checkpoints.split_corpus))
    output:
        train_target="{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/{train_model}/translate/train.{trg}.gz"
    params: 
        train_source="{project_name}/{src}-{trg}/{preprocessing}/train.{src}.gz",
        split_dir="{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/{train_model}/translate/corpus"
    shell: 'bash pipeline/translate/collect.sh {params.split_dir} {output.train_target} {params.train_source} >> {log} 2>&1'

