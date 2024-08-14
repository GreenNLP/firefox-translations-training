# set common variables based on config values

#The cleaned and potentially augmented data that will be used to train the model
#TODO: should the vocab should be built from cleaned data, not augmented, since most augmentation do not result in meaningful change of vocabulary?
clean_corpus_src=f'{config["trainset-dir"]}/{{corpus}}/output/train/corpus.{{src}}-{{trg}}.{{src}}.gz'
clean_corpus_trg=f'{config["trainset-dir"]}/{{corpus}}/output/train/corpus.{{src}}-{{trg}}.{{trg}}.gz'

#The cleaned and potentially augmented dev and eval data
#These aren't used yet, they are here for later adding segmentation rules here as well (for now, using Marian integrated SentencePiece).
dev_source=f'{config["devset-dir"]}/{{testset}}.{{src}}.gz'
dev_target=f'{config["devset-dir"]}/{{testset}}.{{trg}}.gz'
eval_source=f'{config["evalset-dir"]}/{{testset}}.{{src}}.gz'
eval_target=f'{config["evalset-dir"]}/{{testset}}.{{trg}}.gz'
spm_train=f'{config["spm-train"]}'
spm_sample_size=f'{config["spm-sample-size"]}'
user_defined_symbols=config["user-defined-symbols"]

rule train_vocab:
    message: "Training spm vocab"
    log: f"train_spm_vocab.{{corpus}}.{{src}}-{{trg}}.{{spm_vocab_size}}.log"
    conda: "envs/base.yml"
    threads: 2
    input: spm_train=ancient(config["spm-train"]), corpus_src=clean_corpus_src, corpus_trg=clean_corpus_trg
    output: vocab=f"vocab.{{corpus}}.{{src}}-{{trg}}.{{spm_vocab_size}}.spm"
    shell: f'''bash pipeline/train/spm-vocab.sh "{{input.corpus_src}}" "{{input.corpus_trg}}" "{{output.vocab}}" {spm_sample_size} {{threads}} {{spm_vocab_size}} {user_defined_symbols} "{{input.spm_train}}" >> {{log}} 2>&1'''
