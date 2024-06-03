# set common variables based on config values
source=f'{config["clean-dir"]}/{{corpus}}/corpus.{{src}}'
target=f'{config["clean-dir"]}/{{corpus}}/corpus.{{trg}}'
fuzzy_match_cli=f'{config["fuzzy-match-cli"]}'
testset=f'{config["testset-dir"]}/{{testset}}'

# Note that log files are saved in the work directory. To save them in a centralized logs directory would require including the path to the log dir in the config, which can be done. However, it might just be easier for debugging to keep the logs with data.
rule build_fuzzy_index:
    message: "Building fuzzy index"
    log: f"{{corpus}}/build_index.{{src}}.log"
    conda: "envs/base.yml"
    threads: 1
    input: source=source
    output: index=f"{{corpus}}/output/index.{{src}}.fmi"
    shell: f"{fuzzy_match_cli} -c {{input.source}} -N 256"

rule find_fuzzy_matches:
    message: "Finding fuzzies"
    log: f"{{corpus}}/{{type}}-{{testset}}.{{src}}.find_fuzzies.log"
    conda: "envs/base.yml"
    threads: 1
    input: 
        index=rules.build_fuzzy_index.output.index,
        testset=lambda wildcards: source if wildcards.type == "train" else testset 
    output: matches=f"{{corpus}}/output/{{type}}/{{testset}}.{{src}}.matches"
    shell: f"{fuzzy_match_cli} -i {{input.index}} --action match --fuzzy 0.5 --no-perfect --nthreads 1 --nmatch 100 < {{input.testset}} > {{output.matches}}"

rule augment_data_with_fuzzies:
    message: "Augmenting data with fuzzies"
    log: f"{{corpus}}/{{type}}{{testset}}.{{src}}-{{trg}}.augment.log"
    conda: "envs/base.yml"
    threads: 1
    input:
        source=source,
        target=target, 
        matches=f"{{corpus}}/output/{{type}}/{{testset}}.{{src}}.matches",
        testset=lambda wildcards: source if wildcards.type == "train" else testset 
    output: 
        source=f"{{corpus}}/output/{{type}}/{{testset}}.{{src}}-{{trg}}.{{src}}",
        target=f"{{corpus}}/output/{{type}}/{{testset}}.{{src}}-{{trg}}.{{trg}}"
    shell: "touch {output.source} && touch {output.target}"

