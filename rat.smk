# set common variables based on config values
fuzzy_match_cli=f'{config["fuzzy-match-cli"]}'

localrules: augment_data_with_fuzzies, augment_data_with_reverse_fuzzies, augment_data_with_mixed_fuzzies, augment_data_with_domain_fuzzies, combine_targetsim_and_sourcesim

wildcard_constraints:
    src="\w{2,3}",
    trg="\w{2,3}",
    index_type="[\.\-\w\d_]+",
    use_ngrams="(|_ngrams)",
    contrast_factor="\d\.\d",
    nocrawled="(|nocrawled)",
    min_score="\d\.\d",
    combofactor="(1|2)",
    fuzzy_min_score="0\.\d+",
    fuzzy_max_score="(-0\.\d+|)",
    min_fuzzies="\d+",
    max_fuzzies="\d+"
    #index_type="(all_filtered|train)",
    
ruleorder: build_reverse_fuzzy_index > build_fuzzy_domain_index > build_fuzzy_index

# TODO: all_filtered index should be built earlier, like domain indexes
rule build_fuzzy_index:
    message: "Building fuzzy index"
    log: "{project_name}/{src}-{trg}/{preprocessing}/build_index/build_index_{index_type}.log"
    conda: None
    priority: 100
    container: None
    resources: mem_mb=lambda wildcards, input, attempt: (input.size//1000000) * attempt * 20
    envmodules:
        "LUMI/22.12",
        "Boost"
    threads: 2
    input:	
    	index_source="{project_name}/{src}-{trg}/{preprocessing}/{index_type}.{src}.gz",
    	index_target="{project_name}/{src}-{trg}/{preprocessing}/{index_type}.{trg}.gz",
    output: index="{project_name}/{src}-{trg}/{preprocessing}/build_index/index.{index_type}.{src}-{trg}.fmi"
    shell: f'''bash pipeline/rat/build_index.sh "{fuzzy_match_cli}" "{{input.index_source}}" "{{input.index_target}}" "{{output.index}}" >> {{log}} 2>&1'''

use rule build_fuzzy_index as build_reverse_fuzzy_index with:
    log: "{project_name}/{src}-{trg}/{preprocessing}/build_index/build_index_targetsim_{index_type}.log"
    input:	
    	index_source="{project_name}/{src}-{trg}/{preprocessing}/{index_type}.{trg}.gz",
    	index_target="{project_name}/{src}-{trg}/{preprocessing}/{index_type}.{src}.gz"
    output: index="{project_name}/{src}-{trg}/{preprocessing}/build_index/index.targetsim_{index_type}.{trg}-{src}.fmi" 

use rule build_fuzzy_index as build_fuzzy_domain_index with:
    log: "{project_name}/{src}-{trg}/{preprocessing}/domeval_indexes/build_index_{index_type}.log"
    input:	
    	index_source="{project_name}/{src}-{trg}/{preprocessing}/subcorpora/{index_type}.{src}.gz",
    	index_target="{project_name}/{src}-{trg}/{preprocessing}/subcorpora/{index_type}.{trg}.gz",
    output: index="{project_name}/{src}-{trg}/{preprocessing}/domeval_indexes/index.{index_type}.{src}-{trg}.fmi"

ruleorder: find_reverse_fuzzy_matches > find_domain_fuzzy_matches > find_fuzzy_matches

rule find_fuzzy_matches:
    message: "Finding fuzzies"
    log: "{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}{use_ngrams}/find_{index_type}-{set}_matches.log"
    conda: None
    priority: 100
    container: None
    envmodules:
        "LUMI/22.12",
        "Boost"
    threads: workflow.cores*2
    resources: mem_mb=128000
    input:
        source="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/{set}.{src}.gz", 
        target="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/{set}.{trg}.gz",
        index="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/index.{index_type}.{src}-{trg}.fmi",
        priors="{project_name}/{src}-{trg}/download_tc_v2023-09-26/extract_tc_scored_0.7/subset_5M/en-fi.priors" #TODO: non-hardcode this
    output:
        matches="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}{use_ngrams}/{index_type}-{set}.{src}-{trg}.matches.gz"
    params:
        use_ngrams=lambda wildcards: "true" if wildcards.use_ngrams == "_ngrams" else "",
        src="{src}",
        trg="{trg}"
    shell: f'''bash pipeline/rat/find_matches.sh "{fuzzy_match_cli}" "{{input.source}}" "{{input.target}}" "{{input.priors}}" {{threads}} "{{input.index}}" "{{output.matches}}" {{wildcards.contrast_factor}} {{params.src}} {{params.trg}} {{params.use_ngrams}} >> {{log}} 2>&1'''

use rule find_fuzzy_matches as find_reverse_fuzzy_matches with:	
    log: "{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}{use_ngrams}/find_targetsim_{index_type}-{set}_matches.log"
    input:
        source="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/{set}.{trg}.gz", 
        target="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/{set}.{src}.gz",
        index="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/index.targetsim_{index_type}.{trg}-{src}.fmi",
        priors="{project_name}/{src}-{trg}/download_tc_v2023-09-26/extract_tc_scored_0.7/subset_5M/en-fi.priors" #TODO: non-hardcode this
    output: 
        matches="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}{use_ngrams}/targetsim_{index_type}-{set}.{trg}-{src}.matches.gz"
    params:
        use_ngrams=lambda wildcards: "true" if wildcards.use_ngrams == "_ngrams" else "",
        src="{trg}",
        trg="{src}"

use rule find_fuzzy_matches as find_domain_fuzzy_matches with:	
    input:
        source=ancient("{project_name}/{src}-{trg}/{tc_processing}/domeval.{src}.gz"), 
        target=ancient("{project_name}/{src}-{trg}/{tc_processing}/domeval.{trg}.gz"),
        index="{project_name}/{src}-{trg}/{tc_processing}/domeval_indexes/index.{index_type}.{src}-{trg}.fmi",
        priors="{project_name}/{src}-{trg}/download_tc_v2023-09-26/extract_tc_scored_0.7/subset_5M/en-fi.priors" #TODO: non-hardcode this

ruleorder: augment_data_with_domain_fuzzies > augment_data_with_fuzzies

rule augment_data_with_fuzzies:
    message: "Augmenting data with fuzzies"
    wildcard_constraints:
        fuzzy_min_score="0\.\d+",
        fuzzy_max_score="(-0\.\d+|)",
        min_fuzzies="\d+",
        max_fuzzies="\d+",
        set="[_\-\w\d]+",
    log: "{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}{use_ngrams}/augment_train_{fuzzy_min_score}{fuzzy_max_score}_{min_fuzzies}_{max_fuzzies}/augment_{index_type}-{set}_matches.log"
    conda: None
    container: None
    priority: 100
    threads: 1
    resources: mem_mb=60000
    input:
        augment_source="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/{set}.{src}.gz", 
        augment_target="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/{set}.{trg}.gz",
        matches="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}{use_ngrams}/{index_type}-{set}.{src}-{trg}.matches.gz"
    output: 
        source="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}{use_ngrams}/augment_train_{fuzzy_min_score}{fuzzy_max_score}_{min_fuzzies}_{max_fuzzies}/{index_type}-{set}.{src}.gz",
        target="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}{use_ngrams}/augment_train_{fuzzy_min_score}{fuzzy_max_score}_{min_fuzzies}_{max_fuzzies}/{index_type}-{set}.{trg}.gz",
        source_nobands="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}{use_ngrams}/augment_train_{fuzzy_min_score}{fuzzy_max_score}_{min_fuzzies}_{max_fuzzies}/nobands_{index_type}-{set}.{src}.gz",
        target_nobands="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}{use_ngrams}/augment_train_{fuzzy_min_score}{fuzzy_max_score}_{min_fuzzies}_{max_fuzzies}/nobands_{index_type}-{set}.{trg}.gz"
    params:
        fuzzy_max_score=lambda wildcards: "1" if wildcards.fuzzy_max_score == "" else wildcards.fuzzy_max_score.replace("-",""),
        mix_matches="",
        extra_args=lambda wildcards: "--lines_to_augment 2000 --exclude_non_augmented" if wildcards.set == "cleandev" else ""
    shell: '''python pipeline/rat/augment.py \
    --src_file_path "{input.augment_source}" \
    --trg_file_path "{input.augment_target}" \
    --src_lang {wildcards.src} \
    --trg_lang {wildcards.trg} \
    --score_file "{input.matches}" \
    --mix_score_file "{params.mix_matches}" \
    --src_output_path "{output.source}" \
    --trg_output_path "{output.target}" \
    --min_score {wildcards.fuzzy_min_score} \
    --max_score {params.fuzzy_max_score} \
    --min_fuzzies {wildcards.min_fuzzies} \
    --max_fuzzies {wildcards.max_fuzzies} \
    {params.extra_args} >> {log} 2>&1 && \
    {{ zcat {output.source} | sed "s/FUZZY_BREAK_[0-9]/FUZZY_BREAK/g" | gzip > {output.source_nobands} ; }} >> {log} 2>&1 &&\
    ln {output.target} {output.target_nobands} >> {log} 2>&1'''

#TODO: reorganize the concept of augmentation. The training data can be augmented with train, all_filtered, train_targetsim, all_filtered_target_sim
use rule augment_data_with_fuzzies as augment_data_with_reverse_fuzzies with:
    log: "{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}{use_ngrams}/augment_train_{fuzzy_min_score}{fuzzy_max_score}_{min_fuzzies}_{max_fuzzies}/augment_targetsim_{index_type}-{set}_matches.log"
    input:
        augment_source="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/{set}.{src}.gz", 
        augment_target="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/{set}.{trg}.gz",
        matches="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}{use_ngrams}/targetsim_{index_type}-{set}.{trg}-{src}.matches.gz"
    output: 
        source="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}{use_ngrams}/augment_train_{fuzzy_min_score}{fuzzy_max_score}_{min_fuzzies}_{max_fuzzies}/targetsim_{index_type}-{set}.{src}.gz",
        target="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}{use_ngrams}/augment_train_{fuzzy_min_score}{fuzzy_max_score}_{min_fuzzies}_{max_fuzzies}/targetsim_{index_type}-{set}.{trg}.gz",
        source_nobands="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}{use_ngrams}/augment_train_{fuzzy_min_score}{fuzzy_max_score}_{min_fuzzies}_{max_fuzzies}/nobands_targetsim_{index_type}-{set}.{src}.gz",
        target_nobands="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}{use_ngrams}/augment_train_{fuzzy_min_score}{fuzzy_max_score}_{min_fuzzies}_{max_fuzzies}/nobands_targetsim_{index_type}-{set}.{trg}.gz"

use rule augment_data_with_fuzzies as augment_data_with_mixed_fuzzies with:
    log: "{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}{use_ngrams}/augment_train_{fuzzy_min_score}{fuzzy_max_score}_{min_fuzzies}_{max_fuzzies}/augment_mixedsim_{index_type}-{set}_matches.log"
    input:
        augment_source="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/{set}.{src}.gz", 
        augment_target="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/{set}.{trg}.gz",
        matches="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}{use_ngrams}/{index_type}-{set}.{src}-{trg}.matches.gz",
        mix_matches="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}{use_ngrams}/targetsim_{index_type}-{set}.{trg}-{src}.matches.gz"
    output: 
        source="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}{use_ngrams}/augment_train_{fuzzy_min_score}{fuzzy_max_score}_{min_fuzzies}_{max_fuzzies}/mixedsim_{index_type}-{set}.{src}.gz",
        target="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}{use_ngrams}/augment_train_{fuzzy_min_score}{fuzzy_max_score}_{min_fuzzies}_{max_fuzzies}/mixedsim_{index_type}-{set}.{trg}.gz",
        source_nobands="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}{use_ngrams}/augment_train_{fuzzy_min_score}{fuzzy_max_score}_{min_fuzzies}_{max_fuzzies}/nobands_mixedsim_{index_type}-{set}.{src}.gz",
        target_nobands="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}{use_ngrams}/augment_train_{fuzzy_min_score}{fuzzy_max_score}_{min_fuzzies}_{max_fuzzies}/nobands_mixedsim_{index_type}-{set}.{trg}.gz"
    params:
        extra_args=lambda wildcards: "--lines_to_augment 2000 --exclude_non_augmented" if wildcards.set == "cleandev" else "",
        fuzzy_max_score=lambda wildcards: "1" if wildcards.fuzzy_max_score == "" else wildcards.fuzzy_max_score.replace("-",""),
        mix_matches="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}{use_ngrams}/targetsim_{index_type}-{set}.{trg}-{src}.matches.gz"

use rule augment_data_with_fuzzies as augment_data_with_domain_fuzzies with:	
    wildcard_constraints:
        set="domeval"
    input:
        augment_source=ancient("{project_name}/{src}-{trg}/{tc_processing}/{set}.{src}.gz"), 
        augment_target=ancient("{project_name}/{src}-{trg}/{tc_processing}/{set}.{trg}.gz"),
        matches=ancient("{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}{use_ngrams}/{index_type}-{set}.{src}-{trg}.matches.gz")
        
rule combine_targetsim_and_sourcesim:
    log: "{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}{use_ngrams}/augment_train_{fuzzy_min_score}{fuzzy_max_score}_{min_fuzzies}_{max_fuzzies}/augment_combosim{combofactor}_{index_type}-{set}_matches.log"
    input:
        sourcesim_src="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}{use_ngrams}/augment_train_{fuzzy_min_score}{fuzzy_max_score}_{min_fuzzies}_{max_fuzzies}/{index_type}-{set}.{src}.gz",
        sourcesim_trg="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}{use_ngrams}/augment_train_{fuzzy_min_score}{fuzzy_max_score}_{min_fuzzies}_{max_fuzzies}/{index_type}-{set}.{trg}.gz",
        targetsim_src="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}{use_ngrams}/augment_train_{fuzzy_min_score}{fuzzy_max_score}_{min_fuzzies}_{max_fuzzies}/targetsim_{index_type}-{set}.{src}.gz",
        targetsim_trg="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}{use_ngrams}/augment_train_{fuzzy_min_score}{fuzzy_max_score}_{min_fuzzies}_{max_fuzzies}/targetsim_{index_type}-{set}.{trg}.gz"
    output: 
        source="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}{use_ngrams}/augment_train_{fuzzy_min_score}{fuzzy_max_score}_{min_fuzzies}_{max_fuzzies}/combosim{combofactor}_{index_type}-{set}.{src}.gz",
        target="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}{use_ngrams}/augment_train_{fuzzy_min_score}{fuzzy_max_score}_{min_fuzzies}_{max_fuzzies}/combosim{combofactor}_{index_type}-{set}.{trg}.gz",
        source_nobands="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}{use_ngrams}/augment_train_{fuzzy_min_score}{fuzzy_max_score}_{min_fuzzies}_{max_fuzzies}/nobands_combosim{combofactor}_{index_type}-{set}.{src}.gz",
        target_nobands="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}{use_ngrams}/augment_train_{fuzzy_min_score}{fuzzy_max_score}_{min_fuzzies}_{max_fuzzies}/nobands_combosim{combofactor}_{index_type}-{set}.{trg}.gz"
    shell:
        '''python pipeline/rat/combosim.py --combination_factor {wildcards.combofactor} --source {input.sourcesim_src} --source_targetsim {input.targetsim_src} --target {input.sourcesim_trg} --target_targetsim {input.targetsim_trg} >> {log} 2>&1'''