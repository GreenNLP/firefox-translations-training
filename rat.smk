# set common variables based on config values

#source and target specify the corpus that is used to create the index
source=f'{config["clean-dir"]}/{{corpus}}/corpus.{{src}}.gz'
target=f'{config["clean-dir"]}/{{corpus}}/corpus.{{trg}}.gz'
fuzzy_match_cli=f'{config["fuzzy-match-cli"]}'

#testset specifies the corpus for which fuzzies are looked for and augmented
testset_source=f'{config["testset-dir"]}/{{testset}}.{{src}}.gz'
testset_target=f'{config["testset-dir"]}/{{testset}}.{{trg}}.gz'

# Note that log files are saved in the work directory. To save them in a centralized logs directory would require including the path to the log dir in the config, which can be done. However, it might just be easier for debugging to keep the logs with data.
rule build_fuzzy_index:
    message: "Building fuzzy index"
    log: f"{{corpus}}/output/build_index.{{src}}-{{trg}}.log"
    conda: "envs/base.yml"
    threads: workflow.cores
    input: source=source,target=target
    output: index=f"{{corpus}}/output/index.{{src}}-{{trg}}.fmi"
    shell: f'''bash pipeline/rat/build_index.sh "{fuzzy_match_cli}" "{{input.source}}" "{{input.target}}" {{threads}} "{{output.index}}" >> {{log}} 2>&1'''

rule find_fuzzy_matches:
    message: "Finding fuzzies"
    log: f"{{corpus}}/output/{{type}}/{{testset}}.{{src}}-{{trg}}.find_fuzzies.log"
    conda: "envs/base.yml"
    threads: workflow.cores
    input: 
        index=rules.build_fuzzy_index.output.index,
        testset=lambda wildcards: source if wildcards.type == "train" else testset_source 
    output: matches=f"{{corpus}}/output/{{type}}/{{testset}}.{{src}}-{{trg}}.{{src}}.matches"
    shell: f'''bash pipeline/rat/find_matches.sh "{{input.testset}}" "{fuzzy_match_cli}" "{{input.index}}" {{threads}} "{{output.matches}}" >> {{log}} 2>&1'''

rule augment_data_with_fuzzies:
    message: "Augmenting data with fuzzies"
    log: f"{{corpus}}/output/{{type}}/{{testset}}.{{src}}-{{trg}}.augment.log"
    conda: "envs/base.yml"
    threads: 1
    resources: mem_mb=64000
    input:
        source=source,
        target=target, 
        matches=f"{{corpus}}/output/{{type}}/{{testset}}.{{src}}-{{trg}}.{{src}}.matches",
        testset_source=lambda wildcards: source if wildcards.type == "train" else testset_source,
        testset_target=lambda wildcards: target if wildcards.type == "train" else testset_target
    output: 
        source=f"{{corpus}}/output/{{type}}/{{testset}}.{{src}}-{{trg}}.{{src}}.gz",
        target=f"{{corpus}}/output/{{type}}/{{testset}}.{{src}}-{{trg}}.{{trg}}.gz"
    shell: f'''python pipeline/rat/get_matches.py \
    --src_sentence_file "{{input.testset_source}}" \
    --trg_sentence_file "{{input.testset_target}}" \
    --score_file "{{input.matches}}" \
    --src_augmented_file "{{output.source}}" \
    --trg_augmented_file "{{output.target}}" \
    --index_src_sentence_file "{{input.source}}" \
    --index_trg_sentence_file "{{input.target}}" \
    --fuzzy_separator "FUZZY_BREAK" \
    --min_score 0.5 \
    --min_fuzzies 1 \
    --max_fuzzies 1 >> {{log}} 2>&1'''
