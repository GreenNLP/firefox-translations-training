include: "./configuration.smk" 

# data downloading
# Tatoeba data has dev, test and train in same big tar, this is a rule producing them all,
# use snakemake ruleorder to prioritize it over normal download
ruleorder: download_tatoeba_corpus > download_corpus

rule download_tatoeba_corpus:
    message: "Downloading Tatoeba corpus"
    log: f"{log_dir}/download_corpus/corpus_devset_test/tc_{{version}}.log"
    conda: "envs/base.yml"
    threads: 1
#    group: 'data'
    output: multiext(f"{original}/corpus/tc_{{version}}", f".{src}.gz", f".{trg}.gz"),multiext(f"{original}/devset/tc_{{version}}", f".{src}.gz", f".{trg}.gz"),multiext(f"{original}/eval/tc_{{version}}", f".{src}.gz", f".{trg}.gz")
    params: prefix=f"{original}", version="{version}",max_sents=parallel_max_sents
    shell: 'bash pipeline/data/download-tc-data.sh {src_three_letter} {trg_three_letter} {src} {trg} {params.prefix} {params.version} {params.max_sents}  >> {log} 2>&1'

rule download_corpus:
    message: "Downloading parallel corpus"
    log: f"{log_dir}/download_corpus/{{kind}}/{{dataset}}.log"
    conda: "envs/base.yml"
    threads: 1
#    group: 'data'
    cache: False # caching is broken in snakemake
    wildcard_constraints: kind="corpus|devset|eval"
    output: multiext(f"{original}/{{kind}}/{{dataset}}", f".{src}.gz", f".{trg}.gz")
    params: prefix=f"{original}/{{kind}}/{{dataset}}", dataset="{dataset}"
    shell: 'bash pipeline/data/download-corpus.sh "{params.dataset}" "{params.prefix}"  >> {log} 2>&1'

rule download_mono:
    message: "Downloading monolingual dataset"
    log: f"{log_dir}/download_mono/{{dataset}}.{{lang}}.log"
    conda: "envs/base.yml"
    threads: 1
#    group: 'data'
    cache: False # caching is broken in snakemake
    wildcard_constraints: lang=f"{src}|{trg}"
    output: f'{original}/mono/{{dataset}}.{{lang}}.gz'
    params: max_sent=lambda wildcards: mono_max_sent[wildcards.lang], dataset='{dataset}', lang='{lang}'
    shell: '''bash pipeline/data/download-mono.sh \
                "{params.dataset}" {params.lang} {params.max_sent} "{output}"  >> {log} 2>&1'''

# cleaning

rule clean_corpus:
    message: "Cleaning dataset"
    log: f"{log_dir}/clean_corpus/{{dataset}}.log"
    conda: "envs/base.yml"
#    group: "clean_corpus"
    threads: 16
    input: multiext(f"{original}/corpus/{{dataset}}", f".{src}.gz", f".{trg}.gz")
    output: multiext(f"{clean}/corpus/{{dataset}}", f".{src}.gz", f".{trg}.gz")
    params: prefix_input=f"{original}/corpus/{{dataset}}",prefix_output=f"{clean}/corpus/{{dataset}}",
            dataset=lambda wildcards: dataset_norm(wildcards.dataset)
    shell: '''bash pipeline/clean/clean-corpus.sh "{params.prefix_input}" "{params.prefix_output}" {threads} {params.dataset} \
                >> {log} 2>&1'''

rule clean_mono:
    message: "Cleaning monolingual dataset"
    log: f"{log_dir}/clean_mono/{{dataset}}.{{lang}}.log"
    conda: "envs/base.yml"
    threads: workflow.cores
#    group: "clean_mono{lang}"
    cache: False
    wildcard_constraints: lang=f"{src}|{trg}"
    input: f'{original}/mono/{{dataset}}.{{lang}}.gz'
    output: f'{clean}/mono/{{dataset}}.{{lang}}.gz'
    params: prefix_input=f"{original}/mono/{{dataset}}", prefix_output=f"{clean}/mono/{{dataset}}",
            dataset=lambda wildcards: dataset_norm(wildcards.dataset)
    shell: '''bash pipeline/clean/clean-mono.sh {wildcards.lang} "{params.prefix_input}" "{params.prefix_output}" \
                {threads} {params.dataset} >> {log} 2>&1'''

if 'bicleaner' in config['experiment']:
    bicl_default_threshold = config['experiment']['bicleaner']['default-threshold']
    bicl_dataset_thresholds = config['experiment']['bicleaner']['dataset-thresholds']

    # bicleaner-ai does not work with multiple AMD gpus currently, so set gpu amount to 1
    if rocm_dir:
        #if gpus_num % 8 != 0:
        #    raise ValueError("Only use multiples of 8 for gpu_num on LUMI")       
        bicleaner_ai_gpus = gpus_num
    else:
        bicleaner_ai_gpus = gpus_num	
else:
    bicleaner_type = None    

bicleaner_env = "envs/bicleaner-ai.yml" if bicleaner_type == 'bicleaner-ai' else 'envs/bicleaner.yml'

rule kenlm:
    message: "Installing kenlm"
    log: f"{log_dir}/kenlm.log"
    conda: bicleaner_env
    threads: 4
#        group: 'setup'
    output: directory(f"{bin}/kenlm")
    shell: 'bash pipeline/setup/install-kenlm.sh {kenlm} {threads}  >> {log} 2>&1'

rule bicleaner_pack:
    message: f"Downloading language pack for bicleaner"
    log: f"{log_dir}/bicleaner_pack.log"
    conda: bicleaner_env
#        group: "clean_corpus"
    threads: 1
    input: rules.kenlm.output
    output: directory(f"{biclean}/pack")
    shell: '''bash pipeline/bicleaner/download-pack.sh "{output}" {bicleaner_type} >> {log} 2>&1'''

rule bicleaner:
    message: f"Cleaning corpus using {bicleaner_type}"
    log: f"{log_dir}/bicleaner/{{dataset}}.log"
    conda: bicleaner_env
#       group: "bicleaner"
    threads: (bicleaner_ai_gpus * 8) if bicleaner_type == "bicleaner-ai" else workflow.cores
    resources: gpu=bicleaner_ai_gpus if bicleaner_type == "bicleaner-ai" else 0
    input: ancient(rules.kenlm.output), multiext(f"{clean}/corpus/{{dataset}}", f".{src}.gz", f".{trg}.gz"),
            pack_dir=rules.bicleaner_pack.output
    output: multiext(f"{biclean}/corpus/{{dataset}}", f".{src}.gz", f".{trg}.gz")
    params:
        prefix_input=f"{clean}/corpus/{{dataset}}",prefix_output=f"{biclean}/corpus/{{dataset}}",
        threshold=lambda wildcards: bicl_dataset_thresholds[wildcards.dataset]
                                        if wildcards.dataset in bicl_dataset_thresholds
                                        else bicl_default_threshold
    shell: '''bash pipeline/bicleaner/bicleaner.sh \
                "{params.prefix_input}" "{params.prefix_output}" {params.threshold} {bicleaner_type} {threads} \
                "{input.pack_dir}" >> {log} 2>&1'''


#TODO: this should be combined with the Tatoeba-Challenge download, also the threshould should be configurable, and there should be a split between domains (at least for test purposes)
rule extract_tc_scored:
    message: "Extracting corpora from scored tc training set"
    log: f"{log_dir}/{{corpus}}/extract_tc_scored.log"
    conda: "envs/base.yml"
    threads: workflow.cores
    input: tc_scored
    output: src=f"{biclean_scored}/{{corpus}}/corpus.{src}.gz",trg=f"{biclean_scored}/{{corpus}}/corpus.{trg}.gz",scores=f"{biclean_scored}/{{corpus}}/corpus.scores.gz"
    params: max_sents=parallel_max_sents
    # extract sent pairs with more than 0.8 bicleaner score
    shell: '''zcat {input} | grep -P "(1.000|0.[89]\d\d)$" | head -n {params.max_sents} | tee >(cut -f 1 | gzip > {output.src}) | tee >(cut -f 2 | gzip > {output.trg}) | cut -f 3 | gzip > {output.scores} 2> {log}'''

rule merge_corpus:
    message: "Merging clean parallel datasets"
    log: f"{log_dir}/merge_corpus.log"
    conda: "envs/base.yml"
    threads: workflow.cores
    # group: "clean_corpus"
    input:  expand(f"{clean_corpus_prefix}/{{dataset}}.{{lang}}.gz", dataset=train_datasets, lang=[src, trg]),
            bin=ancient(deduper)
    output: src=clean_corpus_src,trg=clean_corpus_trg
    params: prefix_output=clean_corpus_prefix, 
            prefixes=expand(f"{clean_corpus_prefix}/{{dataset}}", dataset=train_datasets),
            max_sents=parallel_max_sents
    shell: '''bash pipeline/clean/merge-corpus.sh "{params.prefix_output}" {params.max_sents} {params.prefixes} >> {log} 2>&1'''

rule merge_devset:
    message: "Merging devsets"
    log: f"{log_dir}/merge_devset.log"
    conda: "envs/base.yml"
    threads: workflow.cores
    # group: "clean_corpus"
    input:  expand(f"{original}/devset/{{dataset}}.{{lang}}.gz", dataset=valid_datasets, lang=[src, trg]),
            bin=ancient(deduper)
    output: multiext(f"{original}/devset", f".{src}.gz", f".{trg}.gz")
    params: prefix_output=f"{original}/devset", prefixes=expand(f"{original}/devset/{{dataset}}", dataset=valid_datasets)
    shell: '''bash pipeline/clean/merge-corpus.sh "{params.prefix_output}" inf {params.prefixes} >> {log} 2>&1'''

rule merge_mono:
    message: "Merging clean monolingual datasets"
    log: f"{log_dir}/merge_mono_{{lang}}.log"
    conda: "envs/base.yml"
    threads: workflow.cores
    #group "clean_mono{lang}"
    input:
        corpora=lambda wildcards: expand(f"{clean}/mono/{{dataset}}.{{lang}}.gz",
            dataset=mono_datasets[wildcards.lang], lang=wildcards.lang),
            bin=ancient(deduper)
    output: f"{clean}/mono.{{lang}}.gz"
    params: max_sent=lambda wildcards: mono_max_sent[wildcards.lang]
    shell: '''bash pipeline/clean/merge-mono.sh "{output}" {params.max_sent} {input.corpora} >> {log} 2>&1'''

