import langcodes
include: "./configuration.smk" 

wildcard_constraints:
    src="\w{2,3}",
    trg="\w{2,3}"

# data downloading
# Tatoeba data has dev, test and train in same big tar, this is a rule producing them all,
# use snakemake ruleorder to prioritize it over normal download
ruleorder: download_tatoeba_corpus > download_corpus

# light-weight rules can run on login node
localrules: download_corpus, download_tatoeba_corpus, subset_corpus, baseline_preprocessing, use_custom_corpus 

rule download_tatoeba_corpus:
    message: "Downloading Tatoeba corpus"
    log: "{project_name}/{src}-{trg}/download_tc_{version}/download_tc_{version}.log"
    conda: "envs/base.yml"
    wildcard_constraints: version="v\d{4}-\d{2}-\d{2}"
    threads: 1
#    group: 'data'
    output: multiext("{project_name}/{src}-{trg}/download_tc_{version}/train", ".{src}.gz", ".{trg}.gz"),multiext("{project_name}/{src}-{trg}/download_tc_{version}/dev", ".{src}.gz", ".{trg}.gz"),multiext("{project_name}/{src}-{trg}/download_tc_{version}/eval", ".{src}.gz", ".{trg}.gz"), "{project_name}/{src}-{trg}/download_tc_{version}/train.id.gz",
    params: 
        prefix="{project_name}/{src}-{trg}/download_tc_{version}",
        version="{version}"
    shell: 'bash pipeline/data/download-tc-data.sh {wildcards.src} {wildcards.trg} {params.prefix} {params.version} inf >> {log} 2>&1'

#TODO: explicitly defined dev and eval linking, the glob might cause problems
rule extract_tc_scored:
    message: "Extracting corpora from scored tc training set"
    log: "{project_name}/{src}-{trg}/{download_tc_dir}/extract_tc_scored_{min_score}/extract_tc_scored.log"
    conda: "envs/base.yml"
    wildcard_constraints:
        min_score="0\.\d+",
    threads: 1
    input: train_src="{project_name}/{src}-{trg}/{download_tc_dir}/train.{src}.gz", train_trg="{project_name}/{src}-{trg}/{download_tc_dir}/train.{trg}.gz", train_ids="{project_name}/{src}-{trg}/{download_tc_dir}/train.id.gz", scores="../data/scores/{src}-{trg}.scored.gz"
    output: 
        src="{project_name}/{src}-{trg}/{download_tc_dir}/extract_tc_scored_{min_score}/train.{src}.gz",
        trg="{project_name}/{src}-{trg}/{download_tc_dir}/extract_tc_scored_{min_score}/train.{trg}.gz",
        dev_src="{project_name}/{src}-{trg}/{download_tc_dir}/extract_tc_scored_{min_score}/dev.{src}.gz",
        dev_trg="{project_name}/{src}-{trg}/{download_tc_dir}/extract_tc_scored_{min_score}/dev.{trg}.gz",
        eval_src="{project_name}/{src}-{trg}/{download_tc_dir}/extract_tc_scored_{min_score}/eval.{src}.gz",
        eval_trg="{project_name}/{src}-{trg}/{download_tc_dir}/extract_tc_scored_{min_score}/eval.{trg}.gz"
    params:
        input_dir="{project_name}/{src}-{trg}/{download_tc_dir}/",
        output_dir="{project_name}/{src}-{trg}/{download_tc_dir}/extract_tc_scored_{min_score}/"
        
    shell: '''python3 pipeline/data/filter-tc-data.py --source_corpus {input.train_src} --target_corpus {input.train_trg} --id_file {input.train_ids} --score_file {input.scores} --domain_eval_lines 1000 --output_dir {params.output_dir}  --min_score {wildcards.min_score} && ln {params.input_dir}/{{eval,dev}}.*.gz {params.output_dir} >> {log} 2>&1'''

rule baseline_preprocessing:
    message: "Preprocessing data for baseline training"
    log: "{project_name}/{src}-{trg}/{preprocessing}/baseline_preprocessing_{max_dev_sents}/preprocess_baseline.log"
    conda: "envs/base.yml"
    wildcard_constraints:
        max_dev_sents="\d+"
    threads: 1
    input:         
        train_source="{project_name}/{src}-{trg}/{preprocessing}/train.{src}.gz",
        train_target="{project_name}/{src}-{trg}/{preprocessing}/train.{trg}.gz",
        dev_source="{project_name}/{src}-{trg}/{preprocessing}/dev.{src}.gz",
        dev_target="{project_name}/{src}-{trg}/{preprocessing}/dev.{trg}.gz",
        eval_source="{project_name}/{src}-{trg}/{preprocessing}/eval.{src}.gz",
        eval_target="{project_name}/{src}-{trg}/{preprocessing}/eval.{trg}.gz"
    output: 
        train_source="{project_name}/{src}-{trg}/{preprocessing}/baseline_preprocessing_{max_dev_sents}/train.{src}.gz",
        train_target="{project_name}/{src}-{trg}/{preprocessing}/baseline_preprocessing_{max_dev_sents}/train.{trg}.gz",
        dev_source="{project_name}/{src}-{trg}/{preprocessing}/baseline_preprocessing_{max_dev_sents}/dev.{src}.gz",
        dev_target="{project_name}/{src}-{trg}/{preprocessing}/baseline_preprocessing_{max_dev_sents}/dev.{trg}.gz",
        eval_source="{project_name}/{src}-{trg}/{preprocessing}/baseline_preprocessing_{max_dev_sents}/eval.{src}.gz",
        eval_target="{project_name}/{src}-{trg}/{preprocessing}/baseline_preprocessing_{max_dev_sents}/eval.{trg}.gz"
    params:
        input_dir="{project_name}/{src}-{trg}/{preprocessing}/",
        output_dir="{project_name}/{src}-{trg}/{preprocessing}/baseline_preprocessing_{max_dev_sents}/"
    shell:
        """
        ln {params.input_dir}/{{eval,train}}.*.gz {params.output_dir} >> {log} 2>&1 && \
        {{ pigz -dc {input.dev_source} | head -n {wildcards.max_dev_sents} | pigz -c > {output.dev_source} ; }} 2>> {log} && \
        {{ pigz -dc {input.dev_target} | head -n {wildcards.max_dev_sents} | pigz -c > {output.dev_target} ; }} 2>> {log}
        """


rule subset_corpus:
    message: "Extracting N million lines from corpus as training set"
    log: "{project_name}/{src}-{trg}/{download_tc_dir}/extract_tc_scored_{min_score}/subset_{max_train_sents}/subset_corpus.log"
    conda: "envs/base.yml"
    wildcard_constraints:
        max_train_sents="\d+[KM]"
    threads: 1
    input:         
        train_source="{project_name}/{src}-{trg}/{download_tc_dir}/extract_tc_scored_{min_score}/train.{src}.gz",
        train_target="{project_name}/{src}-{trg}/{download_tc_dir}/extract_tc_scored_{min_score}/train.{trg}.gz",
    output: 
        train_source="{project_name}/{src}-{trg}/{download_tc_dir}/extract_tc_scored_{min_score}/subset_{max_train_sents}/train.{src}.gz",
        train_target="{project_name}/{src}-{trg}/{download_tc_dir}/extract_tc_scored_{min_score}/subset_{max_train_sents}/train.{trg}.gz",
        dev_source="{project_name}/{src}-{trg}/{download_tc_dir}/extract_tc_scored_{min_score}/subset_{max_train_sents}/dev.{src}.gz",
        dev_target="{project_name}/{src}-{trg}/{download_tc_dir}/extract_tc_scored_{min_score}/subset_{max_train_sents}/dev.{trg}.gz",
        eval_source="{project_name}/{src}-{trg}/{download_tc_dir}/extract_tc_scored_{min_score}/subset_{max_train_sents}/eval.{src}.gz",
        eval_target="{project_name}/{src}-{trg}/{download_tc_dir}/extract_tc_scored_{min_score}/subset_{max_train_sents}/eval.{trg}.gz",
        all_filtered_source="{project_name}/{src}-{trg}/{download_tc_dir}/extract_tc_scored_{min_score}/subset_{max_train_sents}/all_filtered.{src}.gz",
        all_filtered_target="{project_name}/{src}-{trg}/{download_tc_dir}/extract_tc_scored_{min_score}/subset_{max_train_sents}/all_filtered.{trg}.gz"
    params:
        input_dir="{project_name}/{src}-{trg}/{download_tc_dir}/",
        output_dir="{project_name}/{src}-{trg}/{download_tc_dir}/extract_tc_scored_{min_score}/subset_{max_train_sents}/"
    shell:
        """
        ln {params.input_dir}/{{eval,dev}}.*.gz {params.output_dir} >> {log} 2>&1 && \
        ln {input.train_source} {output.all_filtered_source} >> {log} 2>&1 && \
        ln {input.train_target} {output.all_filtered_target} >> {log} 2>&1 && \
        {{ pigz -dc {input.train_source} | head -n {wildcards.max_train_sents}B | pigz -c > {output.train_source} ; }} 2>> {log} && \
        {{ pigz -dc {input.train_target} | head -n {wildcards.max_train_sents}B | pigz -c > {output.train_target} ; }} 2>> {log}
        """


rule use_custom_corpus:
    message: "Using custom corpus"
    log: "{datadir}/{project_name}/{src}-{trg}/corpus_custom_{dataset}/custom_corpus_{dataset}.log"
    conda: None
    container: None
    threads: 1
#    group: 'data'
    cache: False # caching is broken in snakemake
    wildcard_constraints:
        dataset="[\w\d_-]+",
    output:
        train_source="{datadir}/{project_name}/{src}-{trg}/corpus_custom_{dataset}/train.{src}.gz",
        train_target="{datadir}/{project_name}/{src}-{trg}/corpus_custom_{dataset}/train.{trg}.gz",
        dev_source="{datadir}/{project_name}/{src}-{trg}/corpus_custom_{dataset}/dev.{src}.gz",
        dev_target="{datadir}/{project_name}/{src}-{trg}/corpus_custom_{dataset}/dev.{trg}.gz"
    params: 
        prefix="{datadir}/{dataset}",
        dataset="{dataset}"
    shell: 
        """
        ln "{params.prefix}/train.{wildcards.src}.gz" "{output.train_source}" >> {log} 2>&1 && \
        ln "{params.prefix}/train.{wildcards.trg}.gz" "{output.train_target}" >> {log} 2>&1 && \
        ln "{params.prefix}/dev.{wildcards.src}.gz" "{output.dev_source}" >> {log} 2>&1 && \
        ln "{params.prefix}/dev.{wildcards.trg}.gz" "{output.dev_target}" >> {log} 2>&1
        """

ruleorder: use_custom_eval > download_corpus

rule use_custom_eval:
    message: "Using custom evalset"
    log: "{datadir}/{project_name}/{src}-{trg}/{preprocessing}/custom_eval_{dataset}.log"
    conda: None
    container: None
    threads: 1
#    group: 'data'
    cache: False # caching is broken in snakemake
    wildcard_constraints:
        dataset="[\w\d_]+",
    output:
        eval_source="{datadir}/{project_name}/{src}-{trg}/{preprocessing}/eval-custom_{dataset}.{src}.gz",
        eval_target="{datadir}/{project_name}/{src}-{trg}/{preprocessing}/eval-custom_{dataset}.{trg}.gz",
    params: 
        prefix="{datadir}/{dataset}",
        dataset="{dataset}"
    shell: 
        """
        ln "{params.prefix}/eval.{wildcards.src}.gz" "{output.eval_source}" >> {log} 2>&1 && \
        ln "{params.prefix}/eval.{wildcards.trg}.gz" "{output.eval_target}" >> {log} 2>&1
        """

rule download_corpus:
    message: "Downloading parallel corpus"
    log: "{project_name}/{src}-{trg}/{preprocessing}/download_{kind}-{dataset}.log"
    conda: None
    container: None
    threads: 1
#    group: 'data'
    cache: False # caching is broken in snakemake
    wildcard_constraints:
        kind="corpus|devset|eval",
        dataset="[\w\d_]+",
        max_train_sents="\d+[KM]"
    output:
        source="{project_name}/{src}-{trg}/{preprocessing}/{kind}-{dataset}.{src}.gz",
        target="{project_name}/{src}-{trg}/{preprocessing}/{kind}-{dataset}.{trg}.gz"
    params: 
        prefix="{project_name}/{src}-{trg}/{preprocessing}/{kind}-{dataset}",
        dataset="{dataset}",
        source_lng=lambda wildcards: langcodes.standardize_tag(wildcards.src),
        target_lng=lambda wildcards: langcodes.standardize_tag(wildcards.trg)
    shell: 
        """
        bash pipeline/data/download-corpus.sh "{params.dataset}" "{params.prefix}" "{params.source_lng}" "{params.target_lng}" >> {log} 2>&1 && \
        mv "{params.prefix}.{params.source_lng}.gz" "{output.source}" >> {log} 2>&1 && \
        mv "{params.prefix}.{params.target_lng}.gz" "{output.target}" >> {log} 2>&1
        """

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

