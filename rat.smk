# set common variables based on config values
fuzzy_match_cli=f'{config["fuzzy-match-cli"]}'

wildcard_constraints:
    src="\w{2,3}",
    trg="\w{2,3}",
    index_type="[\.\-\w\d_]+"
    #index_type="(all_filtered|train)"

ruleorder: build_fuzzy_domain_index > build_fuzzy_index

# TODO: all_filtered index should be built earlier, like domain indexes
rule build_fuzzy_index:
    message: "Building fuzzy index"
    log: "{project_name}/{src}-{trg}/{preprocessing}/build_index/build_index_{index_type}.log"
    conda: None
    priority: 100
    container: None
    resources: mem_mb=lambda wildcards, input, attempt: (input.size//1000000) * attempt * 10
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
    log: "{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}/find_{index_type}-{set}_matches.log"
    conda: None
    priority: 100
    container: None
    envmodules:
        "LUMI/22.12",
        "Boost"
    group: "find_fuzzies"
    threads: workflow.cores
    resources: mem_mb=128000
    input:
        source="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/{set}.{src}.gz", 
        target="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/{set}.{trg}.gz",
        index="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/index.{index_type}.{src}-{trg}.fmi"
    output: 
        matches="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}/{index_type}-{set}.{src}-{trg}.matches"
    shell: f'''bash pipeline/rat/find_matches.sh "{fuzzy_match_cli}" "{{input.source}}" {{threads}} "{{input.index}}" "{{output.matches}}" {{wildcards.contrast_factor}} >> {{log}} 2>&1'''

use rule find_fuzzy_matches as find_reverse_fuzzy_matches with:	
    log: "{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}/find_targetsim_{index_type}-{set}_matches.log"
    input:
        source="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/{set}.{trg}.gz", 
        target="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/{set}.{src}.gz",
        index="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/index.targetsim_{index_type}.{trg}-{src}.fmi"
    output: 
        matches="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}/targetsim_{index_type}-{set}.{trg}-{src}.matches"

use rule find_fuzzy_matches as find_domain_fuzzy_matches with:	
    input:
        source="{project_name}/{src}-{trg}/{tc_processing}/domeval.{src}.gz", 
        target="{project_name}/{src}-{trg}/{tc_processing}/domeval.{trg}.gz",
        index="{project_name}/{src}-{trg}/{tc_processing}/domeval_indexes/index.{index_type}.{src}-{trg}.fmi"

ruleorder: augment_data_with_domain_fuzzies > augment_data_with_fuzzies

rule augment_data_with_fuzzies:
    message: "Augmenting data with fuzzies"
    wildcard_constraints:
        fuzzy_min_score="0\.\d+",
        fuzzy_max_score="(-0\.\d+|)",
        min_fuzzies="\d+",
        max_fuzzies="\d+",
        set="[_\-\w\d]+",
    log: "{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}/augment_train_{fuzzy_min_score}{fuzzy_max_score}_{min_fuzzies}_{max_fuzzies}/augment_{index_type}-{set}_matches.log"
    conda: None
    container: None
    priority: 100
    group: "augment"
    threads: 1
    resources: mem_mb=60000
    input:
        index_source="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/{index_type}.{src}.gz", 
        index_target="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/{index_type}.{trg}.gz",
        augment_source="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/{set}.{src}.gz", 
        augment_target="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/{set}.{trg}.gz",
        matches="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}/{index_type}-{set}.{src}-{trg}.matches"
    output: 
        source="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}/augment_train_{fuzzy_min_score}{fuzzy_max_score}_{min_fuzzies}_{max_fuzzies}/{index_type}-{set}.{src}.gz",
        target="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}/augment_train_{fuzzy_min_score}{fuzzy_max_score}_{min_fuzzies}_{max_fuzzies}/{index_type}-{set}.{trg}.gz"
    params:
        max_sents=lambda wildcards: 2000 if wildcards.set == "dev" else -1,
        fuzzy_max_score=lambda wildcards: "1" if wildcards.fuzzy_max_score else wildcards.fuzzy_max_score
    shell: f'''python pipeline/rat/get_matches.py \
    --src_sentence_file "{{input.augment_source}}" \
    --trg_sentence_file "{{input.augment_target}}" \
    --score_file "{{input.matches}}" \
    --src_augmented_file "{{output.source}}" \
    --trg_augmented_file "{{output.target}}" \
    --index_src_sentence_file "{{input.index_source}}" \
    --index_trg_sentence_file "{{input.index_target}}" \
    --lines_to_augment {{params.max_sents}} \
    --min_score {{wildcards.fuzzy_min_score}} \
    --max_score {{params.fuzzy_max_score}} \
    --min_fuzzies {{wildcards.min_fuzzies}} \
    --max_fuzzies {{wildcards.max_fuzzies}} >> {{log}} 2>&1'''

#TODO: reorganize the concept of augmentation. The training data can be augmented with train, all_filtered, train_targetsim, all_filtered_target_sim
use rule augment_data_with_fuzzies as augment_data_with_reverse_fuzzies with:
    log: "{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}/augment_train_{fuzzy_min_score}{fuzzy_max_score}_{min_fuzzies}_{max_fuzzies}/augment_targetsim_{index_type}-{set}_matches.log"
    input:
        index_source="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/{index_type}.{src}.gz", 
        index_target="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/{index_type}.{trg}.gz",
        augment_source="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/{set}.{src}.gz", 
        augment_target="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/{set}.{trg}.gz",
        matches="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}/targetsim_{index_type}-{set}.{trg}-{src}.matches"
    output: 
        source="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}/augment_train_{fuzzy_min_score}{fuzzy_max_score}_{min_fuzzies}_{max_fuzzies}/targetsim_{index_type}-{set}.{src}.gz",
        target="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}/augment_train_{fuzzy_min_score}{fuzzy_max_score}_{min_fuzzies}_{max_fuzzies}/targetsim_{index_type}-{set}.{trg}.gz"
    
use rule augment_data_with_fuzzies as augment_data_with_domain_fuzzies with:	
    input:
        index_source="{project_name}/{src}-{trg}/{tc_processing}/subcorpora/{index_type}.{src}.gz", 
        index_target="{project_name}/{src}-{trg}/{tc_processing}/subcorpora/{index_type}.{trg}.gz",
        augment_source="{project_name}/{src}-{trg}/{tc_processing}/domeval.{src}.gz", 
        augment_target="{project_name}/{src}-{trg}/{tc_processing}/domeval.{trg}.gz",
        matches="{project_name}/{src}-{trg}/{tc_processing}/{preprocessing}/build_index/find_matches_{contrast_factor}/{index_type}-{set}.{src}-{trg}.matches"
