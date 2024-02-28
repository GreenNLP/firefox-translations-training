import yaml
import os
import glob

from snakemake.utils import min_version
from pipeline.bicleaner import packs
from langcodes import *

min_version("6.6.1")

# `include` directive is not supported by Pycharm plugin, moving all rules to one file to enable live checks
# https://github.com/JetBrains-Research/snakecharm/issues/195


### configuration

containerized: 'Ftt.sif'

install_deps = config['deps'] == 'true'
data_root_dir = config.get('root', srcdir("../data"))
cuda_dir = config.get('cuda', os.environ.get("CUDA_INSTALL_ROOT","")) 
cudnn_dir = config.get('cudnn', os.environ.get("CUDNN_INSTALL_ROOT",""))
rocm_dir = config.get('rocm',os.environ.get("ROCM_PATH",""))

gpus_num = config['numgpus']
# marian occupies all GPUs on a machine if `gpus` are not specified
gpus = config['gpus'] if config['gpus'] else ' '.join([str(n) for n in range(int(gpus_num))])
workspace = config['workspace']
marian_cmake = config['mariancmake']
marian_version = config.get('marianversion','marian-dev')

# experiment
# This only works for bilingual models
src = config['experiment'].get('src')
trg = config['experiment'].get('trg')
src_three_letter = config['experiment'].get('src_three_letter')
trg_three_letter = config['experiment'].get('trg_three_letter')

# multilinguality 
o2m_teacher = config['experiment']['one2many-teacher']
o2m_student = config['experiment']['one2many-student']
o2m_backward = config['experiment']['one2many-backward']


# Read langpairs from config; if not given, infer single langpair from source and target langs
langpairs = config['experiment'].get('langpairs')
if not langpairs:
    langpairs = [f"{src}-{trg}"]

experiment = config['experiment']['name']
dirname = config['experiment'].get('dirname')
if not dirname:
    dirname = {src}-{trg}

# Modified variables to fit naming
src="source"
trg="target"

mono_max_sent_src = config['experiment'].get('mono-max-sentences-src')
mono_max_sent_trg = config['experiment'].get('mono-max-sentences-trg')
parallel_max_sents = config['experiment'].get('parallel-max-sentences',"inf")



backward_pretrained = config['experiment'].get('backward-model')
backward_pretrained_vocab = config['experiment'].get('backward-vocab')
vocab_pretrained = config['experiment'].get('vocab')
forward_pretrained = config['experiment'].get('forward-model')

experiment_dir=f"{data_root_dir}/experiments/{dirname}/{experiment}"

# override marian cofings
marian_args = {name: ' '.join([f'--{k} {v}' for k,v in conf.items() ])
               for name, conf in config.get('marian-args',{}).items()}

# There can be multiple opus teachers, but a single teacher can also be provided
# as string, so convert it to list here
opusmt_teacher = config['experiment'].get('opusmt-teacher')
if opusmt_teacher and not isinstance(opusmt_teacher,list):
    opusmt_teacher = [opusmt_teacher]

opusmt_backward = config['experiment'].get('opusmt-backward')

# if no target language token specified, use src (they might be different in rare cases)
target_language_token = config['experiment'].get('target-language-token',trg)

#this is for reverse scoring with multilingual model
source_language_token = config['experiment'].get('target-language-token',src)

# datasets
train_datasets = config['datasets']['train']
valid_datasets = config['datasets']['devtest']
eval_datasets = config['datasets']['test']
mono_src_datasets = config['datasets'].get('mono-src')
mono_trg_datasets = config['datasets'].get('mono-trg')
mono_datasets = {src: mono_src_datasets, trg: mono_trg_datasets}
mono_max_sent = {src: mono_max_sent_src, trg: mono_max_sent_trg}

# parallelization

ensemble = list(range(config['experiment'].get('teacher-ensemble',0)))

split_length = config['experiment']['split-length']

# logging
log_dir = f"{data_root_dir}/logs/{dirname}/{experiment}"
reports_dir = f"{data_root_dir}/reports/{dirname}/{experiment}"

# binaries
cwd = os.getcwd()
third_party_dir = f'{cwd}/3rd_party'

if marian_version == 'lumi-marian':
    marian_dir = f'{third_party_dir}/lumi-marian/build/'
else:
    marian_dir = f'{third_party_dir}/marian-dev/build/'
    
bmt_marian_dir = f'{third_party_dir}/browsermt-marian-dev/build'
trainer = f'{marian_dir}marian'
decoder = f'{marian_dir}marian-decoder'
scorer = f'{marian_dir}marian-scorer'
spm_encoder = f'{marian_dir}spm_encode'
spm_trainer = f'{marian_dir}spm_train'
spm_exporter = f'{marian_dir}spm_export_vocab'
bmt_decoder = f'{bmt_marian_dir}/marian-decoder'
bmt_converter = f'{bmt_marian_dir}/marian-conv'

kenlm = f'{third_party_dir}/kenlm'
fast_align_build = f'{third_party_dir}/fast_align/build'
extract_lex_build = f'{third_party_dir}/extract-lex/build'
preprocess_build_dir=f'{third_party_dir}/preprocess/build'
bin = f'{cwd}/bin'
deduper = f'{cwd}/bin/dedupe'

# data
data_dir = f"{data_root_dir}/data/{dirname}/{experiment}"
clean = f"{data_dir}/clean"
biclean = f"{data_dir}/biclean"
opusfiltered = f"{data_dir}/opusfilter"
cache_dir = f"{data_dir}/cache"
original = f"{data_dir}/original"
translated = f"{data_dir}/translated"
augmented = f"{data_dir}/augmented"
merged = f"{data_dir}/merged"
filtered = f'{data_dir}/filtered'
align_dir = f"{data_dir}/alignment"

# models
student_prefix = config['experiment'].get('student-prefix')
models_dir = f"{data_root_dir}/models/{dirname}/{experiment}"
# Teacher dir
teacher_base_dir = f"{models_dir}/teacher-base"
if opusmt_teacher:
    teacher_base_dir = f"{models_dir}/{{langpair}}/teacher-base"
teacher_finetuned_dir = f"{models_dir}/teacher-finetuned"
if student_prefix:
    student_dir = f"{models_dir}/"+student_prefix+"_student"
    student_finetuned_dir = f"{models_dir}/"+student_prefix+"_student-finetuned"
    speed_dir = f"{models_dir}/"+student_prefix+"_speed"
    exported_dir = f"{models_dir}/"+student_prefix+"_exported"
else:
    student_dir = f"{models_dir}/student"
    student_finetuned_dir = f"{models_dir}/student-finetuned"
    speed_dir = f"{models_dir}/speed"
    exported_dir = f"{models_dir}/exported"
best_model_metric = config['experiment']['best-model']
best_model = f"final.model.npz.best-{best_model_metric}.npz"
backward_dir = f'{models_dir}/backward'
if opusmt_backward:
    backward_dir = f"{models_dir}/{{langpair}}/backward"
spm_sample_size=config['experiment'].get('spm-sample-size')
spm_vocab_size=config['experiment'].get('spm-vocab-size',"32000")

#forward pretrained models are trained with sentencepiece integration, the value is a path to the directory
if forward_pretrained:
    teacher_base_dir = forward_pretrained
    #this means that the when the model dirs are expanded, the result is only the teacher_base_dir
    ensemble = [""] 


#default vocab path used with base ftt
vocab_path = vocab_pretrained or f"{models_dir}/vocab/vocab.spm"

if opusmt_backward:
   backward_vocab = f"{backward_dir}/vocab.yml"
else:
   backward_vocab = vocab_path

#evaluation
eval_data_dir = f"{original}/{{langpair}}/eval"
eval_res_dir = f"{models_dir}/evaluation"
eval_backward_dir = f'{eval_res_dir}/backward'
if student_prefix:
    eval_student_dir = f'{eval_res_dir}/'+student_prefix+'_student'
    eval_student_finetuned_dir = f'{eval_res_dir}/'+student_prefix+'_student-finetuned'
    eval_speed_dir = f'{eval_res_dir}/'+student_prefix+'_speed'
else:
    eval_student_dir = f'{eval_res_dir}/student'
    eval_student_finetuned_dir = f'{eval_res_dir}/student-finetuned'
    eval_speed_dir = f'{eval_res_dir}/speed'
eval_teacher_ens_dir = f'{eval_res_dir}/teacher-ensemble'

# set common environment variables
envs = f'''SRC="source" TRG="target" MARIAN="{marian_dir}" BMT_MARIAN="{bmt_marian_dir}" GPUS="{gpus}" WORKSPACE={workspace} \
BIN="{bin}" CUDA_DIR="{cuda_dir}" CUDNN_DIR="{cudnn_dir}" ROCM_PATH="{rocm_dir}" COMPRESSION_CMD=pigz ARTIFACT_EXT=gz'''
# CUDA_VISIBLE_DEVICES is used by bicleaner ai. slurm sets this variable
# it can be overriden manually by 'gpus' config setting to split GPUs in local mode
if config['gpus']:
    envs += f' CUDA_VISIBLE_DEVICES="{gpus}" '

### workflow options

results = [
    f'{exported_dir}/model.{dirname}.intgemm.alphas.bin.gz',
    f'{exported_dir}/lex.50.50.{dirname}.s2t.bin.gz',
    f'{exported_dir}/vocab.{dirname}.spm.gz',
    f'{experiment_dir}/config.yml',
    *expand(f'{eval_student_dir}/{{langpair}}/{{dataset}}.metrics',dataset=eval_datasets, langpair=langpairs),
    *expand(f'{eval_student_finetuned_dir}/{{langpair}}/{{dataset}}.metrics',dataset=eval_datasets, langpair=langpairs),
    *expand(f'{eval_speed_dir}/{{langpair}}/{{dataset}}.metrics',dataset=eval_datasets, langpair=langpairs)
    ]

#don't evaluate opus mt teachers or pretrained teachers (TODO: fix sp issues with opusmt teacher evaluation)
if not (opusmt_teacher or forward_pretrained):
    results.extend(expand(f'{eval_res_dir}/teacher-base0-{{ens}}/{{langpair}}/{{dataset}}.metrics',ens=ensemble, dataset=eval_datasets, langpair=langpairs))

if len(ensemble) > 1:
    results.extend(expand(f'{eval_teacher_ens_dir}/{{langpair}}/{{dataset}}.metrics', dataset=eval_datasets, langpair=langpairs))

#if install_deps:
#    results.append("/tmp/flags/setup.done")

#three options for backward model: pretrained path, url to opus-mt, or train backward
if backward_pretrained:
    do_train_backward = False
    backward_dir = backward_pretrained
elif opusmt_backward:
    do_train_backward = False 
else:
    # don't evaluate pretrained model
    results.extend(expand(f'{eval_backward_dir}/{{langpair}}/{{dataset}}.metrics',dataset=eval_datasets, langpair=langpairs))
    do_train_backward=True

# bicleaner


if 'bicleaner' in config['experiment']:
    bicl_default_threshold = config['experiment']['bicleaner']['default-threshold']
    bicl_dataset_thresholds = config['experiment']['bicleaner']['dataset-thresholds']

    bicleaner_type = packs.find(src, trg)
else:
    bicleaner_type = None    

if bicleaner_type == 'bicleaner-ai':
    if marian_version == 'lumi-marian':
        bicleaner_env = 'envs/bicleaner-ai-lumi.yml'
    else:
        bicleaner_env = 'envs/bicleaner-ai.yml'
else:
    bicleaner_env = 'envs/bicleaner.yml' 

if bicleaner_type:
    clean_corpus_prefix = f'{biclean}/corpus'
    teacher_corpus = f'{biclean}/corpus'
    use_bicleaner = True
else:
    clean_corpus_prefix = f'{clean}/corpus'
    teacher_corpus = f'{clean}/corpus'
    use_bicleaner = False


# opusfilter

if 'opusfilter' in config['experiment']:
    opusfilter_config = config['experiment']['opusfilter'].get('config')
    if not opusfilter_config:
        opusfilter_config = "default"
    use_opusfilter = True
    clean_corpus_prefix=f'{opusfiltered}/{{langpair}}/corpus'
    teacher_corpus = f'{opusfiltered}/corpus'
else:
    use_opusfilter = False
    clean_corpus_prefix = f'{clean}/{{langpair}}/corpus'
    teacher_corpus = f'{clean}/corpus'

clean_corpus_src = f'{clean_corpus_prefix}.source.gz'
clean_corpus_trg = f'{clean_corpus_prefix}.target.gz'

# opustrainer

if 'opustrainer' in config['experiment']:
    opustrainer_model = config['experiment']['opustrainer']['model']
    opustrainer_config = config['experiment']['opustrainer']['path']
    if opustrainer_model == 'student': # Should be modified to include teacher and backward model training with OpusTrainer
        do_train_student_opustrainer = True
    else:
        do_train_student_opustrainer = False
else:
        do_train_student_opustrainer = False

# augmentation

if mono_trg_datasets and not (opusmt_teacher or forward_pretrained):
    teacher_corpus = f'{augmented}/corpus'
    augment_corpus = True
    final_teacher_dir = teacher_finetuned_dir
    results.extend(expand(f'{eval_res_dir}/teacher-finetuned0-{{ens}}/{{dataset}}.metrics',ens=ensemble, dataset=eval_datasets))
else:
    augment_corpus = False
    final_teacher_dir = teacher_base_dir


### helper functions

def find_parts(wildcards, checkpoint):
    checkpoint_output = checkpoint.get(**wildcards).output[0]
    return glob_wildcards(os.path.join(checkpoint_output,"file.{part,\d+}")).part

def dataset_norm(name: str):
    return name.replace('/','_')

def get_args(section):
    return marian_args.get(section) or ""

### rules

shell.prefix(f"{envs} ")

rule all:
    input: results

localrules: experiment

rule experiment:
    message: "Saving experiment metadata"
    output: f'{experiment_dir}/config.yml'
    priority: 100
    run:
        os.makedirs(experiment_dir, exist_ok=True)
        with open(f'{experiment_dir}/config.yml', 'w') as f:
            yaml.dump(config, f)

# todo: fix jobs grouping in cluster mode

# setup

if install_deps:
    rule setup:
        message: "Installing dependencies"
        log: f"{log_dir}/install-deps.log"
        conda: "envs/base.yml"
        priority: 99
        # group: 'setup'
        output: touch("/tmp/flags/setup.done")  # specific to local machine
        shell: 'bash pipeline/setup/install-deps.sh >> {log} 2>&1'

rule marian:
    message: "Compiling marian"
    log: f"{log_dir}/compile-{{marian_type}}.log"
    conda: "envs/base.yml"
    threads: 16
    resources: gpu=1
 #   group: 'setup'
    output:
        trainer=protected(f"{third_party_dir}/{{marian_type}}/build/marian"),
        decoder=protected(f"{third_party_dir}/{{marian_type}}/build/marian-decoder"),
        scorer=protected(f"{third_party_dir}/{{marian_type}}/build/marian-scorer"),
        converter=protected(f'{third_party_dir}/{{marian_type}}/build/marian-conv'),
        spm_trainer=protected(f'{third_party_dir}/{{marian_type}}/build/spm_train'),
        spm_encoder=protected(f'{third_party_dir}/{{marian_type}}/build/spm_encode'),
        spm_exporter=protected(f'{third_party_dir}/{{marian_type}}/build/spm_export_vocab')
    params: build_dir=f'{third_party_dir}/{{marian_type}}/build',marian_type=f'{{marian_type}}'
    shell: 'bash pipeline/setup/compile-{params.marian_type}.sh {params.build_dir} {threads} {marian_cmake} >> {log} 2>&1'

rule fast_align:
    message: "Compiling fast align"
    log: f"{log_dir}/compile-fast-align.log"
    conda: "envs/base.yml"
    threads: 4
#    group: 'setup'
    output: fast_align=protected(f"{bin}/fast_align"), atools=protected(f"{bin}/atools")
    shell: 'bash pipeline/setup/compile-fast-align.sh {fast_align_build} {threads}  >> {log} 2>&1'

rule compile_preprocess:
    message: "Compiling preprocess"
    log: f"{log_dir}/compile-preprocess.log"
    conda: "envs/base.yml"
    threads: 4
    # group: 'setup'
    output: deduper=f'{bin}/dedupe'
    shell: 'bash pipeline/setup/compile-preprocess.sh {preprocess_build_dir} {threads}  >> {log} 2>&1'

rule extract_lex:
    message: "Compiling fast align"
    log: f"{log_dir}/compile-extract-lex.log"
    conda: "envs/base.yml"
    threads: 4
#    group: 'setup'
    output: protected(f"{bin}/extract_lex")
    shell: 'bash pipeline/setup/compile-extract-lex.sh {extract_lex_build} {threads} >> {log} 2>&1'

# Tatoeba download commented out for testing

# data downloading
# TODO: Tatoeba data has dev, test and train in same big tar, make a rule producing them all,
# and use snakemake ruleorder to prioritize it over this
ruleorder: download_tatoeba_corpus > download_corpus

rule download_tatoeba_corpus:
    message: "Downloading Tatoeba corpus"
    log: f"{log_dir}/download_corpus/corpus_devset_test/tc_{{version}}_{{langpair}}.log"
    conda: "envs/base.yml"
    threads: 1
    output: multiext(f"{original}/{{langpair}}/corpus/tc_{{version}}", ".source.gz", ".target.gz"),
            multiext(f"{original}/{{langpair}}/devset/tc_{{version}}", ".source.gz", ".target.gz"),
            multiext(f"{original}/{{langpair}}/eval/tc_{{version}}", ".source.gz", ".target.gz")
    params: prefix=f"{original}/{{langpair}}",
            version="{version}",max_sents=parallel_max_sents,
            src_lang=lambda wildcards: wildcards.langpair.split('-')[0],
            trg_lang=lambda wildcards: wildcards.langpair.split('-')[1],
            src_three_letter=lambda wildcards: Language.get(wildcards.langpair.split('-')[0]).to_alpha3(), 
            trg_three_letter=lambda wildcards: Language.get(wildcards.langpair.split('-')[1]).to_alpha3()
    shell: 'bash pipeline/data/download-tc-data.sh "{params.src_three_letter}" "{params.trg_three_letter}" "{params.src_lang}" "{params.trg_lang}" "{params.prefix}" "{params.version}" {params.max_sents}  >> {log} 2>&1'

rule download_corpus:
    message: "Downloading parallel corpus"
    log: f"{log_dir}/download_corpus/{{kind}}/{{dataset}}_{{langpair}}.log"
    conda: "envs/base.yml"
    threads: 1
#    group: 'data'
    cache: False # caching is broken in snakemake
    wildcard_constraints: kind="corpus|devset|eval"
    output: multiext(f"{original}/{{langpair}}/{{kind}}/{{dataset}}", ".source.gz", ".target.gz")
    params: prefix=f"{original}/{{langpair}}/{{kind}}/{{dataset}}",
            dataset="{dataset}", src_lang=lambda wildcards: wildcards.langpair.split('-')[0], trg_lang=lambda wildcards: wildcards.langpair.split('-')[1]
    shell: 'bash pipeline/data/download-corpus.sh "{params.dataset}" "{params.prefix}" "{params.src_lang}" "{params.trg_lang}"  >> {log} 2>&1'

rule download_mono: # TO DO
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
    log: f"{log_dir}/clean_corpus/{{dataset}}_{{langpair}}.log"
    conda: "envs/base.yml"
#    group: "clean_corpus"
    threads: workflow.cores
    input: multiext(f"{original}/{{langpair}}/corpus/{{dataset}}", f".source.gz", f".target.gz")
    output: multiext(f"{clean_corpus_prefix}/{{dataset}}", f".source.gz", f".target.gz")
    params: prefix_input=f"{original}/{{langpair}}/corpus/{{dataset}}",prefix_output=f"{clean_corpus_prefix}/{{dataset}}",
            dataset=lambda wildcards: dataset_norm(wildcards.dataset), src_lang=lambda wildcards: wildcards.langpair.split('-')[0], trg_lang=lambda wildcards: wildcards.langpair.split('-')[1]
    shell: '''bash pipeline/clean/clean-corpus.sh "{params.prefix_input}" "{params.prefix_output}" {threads} {params.dataset} "{params.src_lang}" "{params.trg_lang}" \
                >> {log} 2>&1'''

rule clean_mono: # TODO
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

if use_bicleaner: # TODO
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
        threads: gpus_num * 2 if bicleaner_type == "bicleaner-ai" else workflow.cores
        resources: gpu=gpus_num if bicleaner_type == "bicleaner-ai" else 0, mem_mb=128000
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

if use_opusfilter:
    ruleorder: run_opusfilter > clean_corpus
        
    rule run_opusfilter:
        message: "Cleaning dataset with opusfilter"
        log: f"{log_dir}/opusfilter/{{dataset}}_{{langpair}}.log"
        conda: "envs/base.yml"
        threads: workflow.cores
        input: multiext(f"{original}/{{langpair}}/corpus/{{dataset}}", f".source.gz", f".target.gz",)
        output: multiext(f"{clean_corpus_prefix}/{{dataset}}", f".source.gz", f".target.gz")
        params: input_prefixes=multiext(f"{original}/{{langpair}}/corpus/{{dataset}}", f".source.gz", f".target.gz"),
                output_prefixes=multiext(f"{clean_corpus_prefix}/{{dataset}}", f".source.gz", f".target.gz"),
                src_lang=lambda wildcards: wildcards.langpair.split('-')[0], trg_lang=lambda wildcards: wildcards.langpair.split('-')[1]
        shell: '''python pipeline/clean/run-opusfilter.py "{params.input_prefixes}" "{params.output_prefixes}" "{params.src_lang}" "{params.trg_lang}" "{opusfilter_config}"\
                    >> {log} 2>&1'''

rule merge_corpus_langpair:
    message: "Merging clean parallel datasets per langpair"
    log: f"{log_dir}/merge_corpus_{{langpair}}.log"
    conda: "envs/base.yml"
    threads: workflow.cores
    # group: "clean_corpus"
    input:  expand(f"{clean_corpus_prefix}/{{dataset}}.{{lang}}.gz", dataset=train_datasets, lang=['source', 'target'], allow_missing=True),
            bin=ancient(deduper)
    output: src=f"{clean_corpus_prefix}.source.gz",trg=f"{clean_corpus_prefix}.target.gz"
    params: prefix_output=f"{clean_corpus_prefix}",
            prefixes=expand(f"{clean_corpus_prefix}/{{dataset}}", dataset=train_datasets, allow_missing=True),
            max_sents=parallel_max_sents
    shell: '''bash pipeline/clean/merge-corpus.sh "{params.prefix_output}" {params.max_sents} {params.prefixes} >> {log} 2>&1'''

rule merge_devset_langpair:
    message: "Merging devsets per langpair"
    log: f"{log_dir}/merge_devset_{{langpair}}.log"
    conda: "envs/base.yml"
    threads: workflow.cores
    # group: "clean_corpus"
    input:  expand(f"{original}/{{langpair}}/devset/{{dataset}}.{{lang}}.gz", dataset=valid_datasets, lang=['source', 'target'], allow_missing=True),
            bin=ancient(deduper)
    output: multiext(f"{original}/{{langpair}}/devset", f".source.gz", f".target.gz")
    params: prefix_output=f"{original}/{{langpair}}/devset", prefixes=expand(f"{original}/{{langpair}}/devset/{{dataset}}", dataset=valid_datasets, allow_missing=True)
    shell: '''bash pipeline/clean/merge-corpus.sh "{params.prefix_output}" inf {params.prefixes} >> {log} 2>&1'''
 
rule merge_mono: # TO DO
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

# augmentation and teacher training

if not vocab_pretrained:
    rule train_vocab:
        message: "Training spm vocab"
        log: f"{log_dir}/train_vocab.log"
        conda: "envs/base.yml"
        threads: 2
        input: bin=ancient(spm_trainer), corpus_src=f"{teacher_corpus}.source.gz",corpus_trg=f"{teacher_corpus}.target.gz"
        output: vocab_path
        params: prefix_test=f"{original}/devset", 
                trgs = [Language.get(langpair.split('-')[1]).to_alpha3() for langpair in langpairs]
        shell: '''bash pipeline/train/spm-vocab.sh "{input.corpus_src}" "{input.corpus_trg}" "{output}" \
                "{params.trgs}" "{o2m_student}" {spm_sample_size} {threads} "{spm_vocab_size}" >> {log} 2>&1'''
                # o2m_student should be modified in case teacher trianing is included

rule merge_devset:
    message: "Merging clean parallel datasets"
    log: f"{log_dir}/merge_devset.log"
    conda: "envs/base.yml"
    threads: workflow.cores
    input:  expand(f"{original}/{{langpair}}/devset.{{lang}}.gz", langpair=langpairs, lang=['source.langtagged', 'target']),
            bin=ancient(deduper)
    output: src=f"{original}/devset.source.gz",trg=f"{original}/devset.target.gz"
    params: prefix_input=f"{original}/*/devset", prefix_output=f"{original}/devset"
    shell: '''cat $(echo {params.prefix_input}.source.langtagged.gz | tr ' ' '\n' | tr '\n' ' ') > "{params.prefix_output}.source.gz"
    cat $(echo {params.prefix_input}.target.gz | tr ' ' '\n' | tr '\n' ' ') > "{params.prefix_output}.target.gz" '''

if do_train_backward: 
    mono_trg_file = f'{translated}/{{langpair}}/mono_trg/file.{{part}}'
    deseg_mono_trg_outfile = f'{mono_trg_file}.out'
    
    rule train_backward:
        message: "Training backward model"
        log: f"{log_dir}/train_backward.log"
        conda: "envs/base.yml"
        threads: gpus_num * 2
        resources: gpu=gpus_num
        #group 'backward'
        input:
            rules.merge_devset.output, train_src=f'{teacher_corpus}.{src}.gz',train_trg=f'{teacher_corpus}.{trg}.langtagged.gz',
            devset_trg=f"{original}/devset.target.langtagged.gz",
            bin=ancient(trainer), vocab=vocab_path
        output:  model=f'{backward_dir}/{best_model}'
        params: prefix_train=f"{teacher_corpus}",prefix_test=f"{original}/devset", #modified until we implement bicleaner per language pair, this should be the output of merge_corpus
                args=get_args("training-backward")
        shell: '''bash pipeline/train/train.sh \
                    backward train {trg}.langtagged {src} "{params.prefix_train}" "{params.prefix_test}" "{backward_dir}" \
                    "{input.vocab}" "{best_model_metric}" {params.args} >> {log} 2>&1'''

elif opusmt_backward:
    mono_trg_file = f'{translated}/{{langpair}}/mono_trg/file.{{part}}.{{model_index}}.opusmt'
    deseg_mono_trg_outfile = f'{mono_trg_file}.out.deseg'
    
    rule download_opusmt_backward:
        message: "Downloading OPUS-MT backward model {wildcards.langpair}"
        log: f"{log_dir}/download_backward_{{langpair}}.log"
        conda: "envs/base.yml"
        output: model=f'{backward_dir}/{best_model}',vocab=f'{backward_dir}/vocab.yml',
                model_dir=directory(f'{backward_dir}')
        params: src_three_letter=lambda wildcards: Language.get(wildcards.langpair.split('-')[0]).to_alpha3(),
                trg_three_letter=lambda wildcards: Language.get(wildcards.langpair.split('-')[1]).to_alpha3()
        shell: '''bash pipeline/opusmt/download-model.sh \
                    "{opusmt_backward}" "{backward_dir}" "{best_model}" {params.trg_three_letter} {params.src_three_letter} >> {log} 2>&1''' 

if augment_corpus:
    checkpoint split_mono_trg:
        message: "Splitting monolingual trg dataset"
        log: f"{log_dir}/split_mono_trg.log"
        conda: "envs/base.yml"
        threads: 1
        input: corpora=f"{clean}/mono.{trg}.gz", bin=ancient(deduper)
        output: directory(f'{translated}/mono_trg')
        shell: 'bash pipeline/translate/split-mono.sh {input.corpora} {output} {split_length} >> {log} 2>&1'

    #TODO: make it possible to use multiple backward models, add filtering for backtranslations
    #TODO: add preprocessing and deseg for OPUS-MT backward model backtranslation, currently works only with trained backward model
    rule translate_mono_trg:
        message: "Translating monolingual trg dataset with backward model"
        log: f"{log_dir}/translate_mono_trg/{{part}}.log"
        conda: "envs/base.yml"
        threads: gpus_num * 2
        resources: gpu=gpus_num
        input:
            bin=ancient(decoder), file=mono_trg_file,
            vocab=vocab_path, model=f'{backward_dir}/{best_model}'
        output: file=f'{mono_trg_file}.out'
        params: args = get_args("decoding-backward")
        shell: '''bash pipeline/translate/translate.sh "{input.file}" "{output.file}" "{input.vocab}" {input.model} {params.args} \
                >> {log} 2>&1'''

    rule collect_mono_trg:
        message: "Collecting translated mono trg dataset"
        log: f"{log_dir}/collect_mono_trg.log"
        conda: "envs/base.yml"
        threads: 4
        #group 'mono_trg'
        input:
            lambda wildcards: expand(deseg_mono_trg_outfile,
                part=find_parts(wildcards, checkpoints.split_mono_trg))
        output: f'{translated}/mono.{src}.gz'
        params: src_mono=f"{clean}/mono.{trg}.gz",dir=directory(f'{translated}/mono_trg')
        shell: 'bash pipeline/translate/collect.sh "{params.dir}" "{output}" "{params.src_mono}" "" >> {log} 2>&1'

    rule merge_augmented:
        message: "Merging augmented dataset"
        log: f"{log_dir}/merge_augmented.log"
        conda: "envs/base.yml"
        threads: 4
        #group 'mono_trg'
        input:
            src1=clean_corpus_src,
            src2=rules.collect_mono_trg.output,
            trg1=clean_corpus_trg,
            trg2=rules.split_mono_trg.input.corpora,
            bin=ancient(deduper)
        output: res_src=f'{augmented}/corpus.{src}.gz',res_trg=f'{augmented}/corpus.{trg}.gz'
        shell: '''bash pipeline/translate/merge-corpus.sh \
                    "{input.src1}" "{input.src2}" "{input.trg1}" "{input.trg2}" "{output.res_src}" "{output.res_trg}" "" \
                      >> {log} 2>&1'''


rule add_lang_tag_corpus_src:
    message: "Adding language tag id for corpus translation"
    log: f"{log_dir}/add_langid_corpus_{{langpair}}.log" 
    conda: "envs/base.yml"
    threads: workflow.cores
    input: f"{clean_corpus_prefix}.source.gz", model_dir=f"{final_teacher_dir}0-0/" # BEWARE: only works for one model per language pair
    output: f"{clean_corpus_prefix}.source.langtagged.gz"
    params: prefix=f"{clean_corpus_prefix}",
            trg_three_letter=lambda wildcards: Language.get(wildcards.langpair.split('-')[1]).to_alpha3(),
            suffix="source"
    shell: '''bash pipeline/clean/add-lang-tag.sh "{params.trg_three_letter}" "{params.prefix}" "{o2m_teacher}" "{params.suffix}" "{input.model_dir}" >> {log} 2>&1'''

if do_train_backward:
    rule add_lang_tag_corpus_backward:
        message: "Adding language tag id for backward model training"
        log: f"{log_dir}/add_langid_corpus_{{langpair}}_backward.log" 
        conda: "envs/base.yml"
        threads: workflow.cores
        input: f"{clean_corpus_prefix}.target.gz", model_dir=f'{models_dir}/{{langpair}}/backward'
        output: f"{clean_corpus_prefix}.target.langtagged.gz"
        params: prefix=f"{clean_corpus_prefix}",
                src_three_letter=lambda wildcards: Language.get(wildcards.langpair.split('-')[0]).to_alpha3(),
                suffix="target"
        shell: '''bash pipeline/clean/add-lang-tag.sh "{params.src_three_letter}" "{params.prefix}" "{o2m_backward}" "{params.suffix}" "{input.model_dir}" >> {log} 2>&1'''
    
    rule add_lang_tag_devset_backward:
        message: "Adding language tag id for devset for backward model training"
        log: f"{log_dir}/add_langid_devset_{{langpair}}_backward.log" 
        conda: "envs/base.yml"
        threads: workflow.cores
        input: f"{original}/{{langpair}}/devset.target.gz",  model_dir=f'{models_dir}/{{langpair}}/backward'
        output: f"{original}/{{langpair}}/devset.target.langtagged.gz"
        params: prefix=f"{original}/{{langpair}}/devset",
                src_three_letter=lambda wildcards: Language.get(wildcards.langpair.split('-')[0]).to_alpha3(),
                suffix="target"
        shell: '''bash pipeline/clean/add-lang-tag.sh "{params.src_three_letter}" "{params.prefix}" "{o2m_backward}"  "{params.suffix}"  "{input.model_dir}" >> {log} 2>&1'''

    rule merge_corpus_backward: 
        message: "Merging clean parallel datasets for backward training" 
        log: f"{log_dir}/merge_corpus_backward.log"
        conda: "envs/base.yml"
        threads: workflow.cores
        input:  expand(f"{clean_corpus_prefix}.{{lang}}.gz", langpair=langpairs, lang=['source', 'target.langtagged']),
                bin=ancient(deduper)
        output: trg=f"{teacher_corpus}.target.langtagged.gz"
        params: prefix_input = f"{teacher_corpus}".replace('corpus', ''), prefix_output=f"{teacher_corpus}"
        shell: '''cat $(echo {params.prefix_input}*/corpus.target.langtagged.gz | tr ' ' '\n' | tr '\n' ' ') > "{params.prefix_output}.target.langtagged.gz" '''

    rule merge_devset_backward:
        message: "Merging clean parallel devsets for backward training"
        log: f"{log_dir}/merge_devset_backward.log"
        conda: "envs/base.yml"
        threads: workflow.cores
        input:  expand(f"{original}/{{langpair}}/devset.{{lang}}.gz", langpair=langpairs, lang=['source', 'target.langtagged']),
                bin=ancient(deduper)
        output: trg=f"{original}/devset.target.langtagged.gz"
        params: prefix_input=f"{original}/*/devset", prefix_output=f"{original}/devset"
        shell: '''cat $(echo {params.prefix_input}.target.langtagged.gz | tr ' ' '\n' | tr '\n' ' ') > "{params.prefix_output}.target.langtagged.gz" '''

rule add_lang_tag_devset:
    message: "Adding language tag id for devset"
    log: f"{log_dir}/add_langid_devset_{{langpair}}.log" 
    conda: "envs/base.yml"
    threads: workflow.cores
    input: f"{original}/{{langpair}}/devset.source.gz", model_dir=f"{final_teacher_dir}0-0/" # BEWARE: only works for one model per language pair
    output: f"{original}/{{langpair}}/devset.source.langtagged.gz"
    params: output_dir=f"{original}/{{langpair}}/", prefix=f"{original}/{{langpair}}/devset",
            trg_three_letter=lambda wildcards: Language.get(wildcards.langpair.split('-')[1]).to_alpha3(),
            suffix="source"
    shell: '''bash pipeline/clean/add-lang-tag.sh "{params.trg_three_letter}" "{params.prefix}" "{o2m_teacher}"  "{params.suffix}"  "{input.model_dir}" >> {log} 2>&1'''

rule merge_corpus: 
    message: "Merging clean parallel datasets"
    log: f"{log_dir}/merge_corpus.log"
    conda: "envs/base.yml"
    threads: workflow.cores
    input:  expand(f"{clean_corpus_prefix}.{{lang}}.gz", langpair=langpairs, lang=['source.langtagged', 'target']),
            bin=ancient(deduper)
    output: src=f"{teacher_corpus}.source.gz",trg=f"{teacher_corpus}.target.gz"
    params: prefix_input = f"{teacher_corpus}".replace('corpus', ''), prefix_output=f"{teacher_corpus}"
    shell: '''cat $(echo {params.prefix_input}*/corpus.source.langtagged.gz | tr ' ' '\n' | tr '\n' ' ') > "{params.prefix_output}.source.gz"
    cat $(echo {params.prefix_input}*/corpus.target.gz | tr ' ' '\n' | tr '\n' ' ') > "{params.prefix_output}.target.gz" '''

# Three options for teacher: 1. download opus-mt model, 2. train teacher with pipeline, 3. path to pretrained teacher model
# TODO: make it possible to combine any of the above options, i.e. use opus-mt, train and use 
# pretrained all in the same run. Probably should have a model list where you can define all the 
# models to use, and then prefixes (opusmt_, train_, pretrained_, nllb_ etc.) determine how the models are
# created/used/connected to (in case of e.g. external APIs).
if 'opusmt-teacher' in config['experiment']:
    rule download_teacher_model:
        message: "Downloading OPUS-MT teacher model for {wildcards.langpair}"
        log: f"{log_dir}/download_teacher_{{model_index}}-{{ens}}_{{langpair}}.log"
        conda: "envs/base.yml"
        threads: 1
        output: model=f'{models_dir}/{{langpair}}/teacher-base{{model_index}}-{{ens}}/{best_model}',
                vocab=f'{models_dir}/{{langpair}}/teacher-base{{model_index}}-{{ens}}/vocab.yml',
                model_dir=directory(f'{models_dir}/{{langpair}}/teacher-base{{model_index}}-{{ens}}')
        params: teacher_dir=f'{models_dir}/{{langpair}}/teacher-base{{model_index}}-{{ens}}',
                teacher_url=lambda wildcards: opusmt_teacher[int(wildcards.model_index)],
                src_three_letter=lambda wildcards: Language.get(wildcards.langpair.split('-')[0]).to_alpha3(),
                trg_three_letter=lambda wildcards: Language.get(wildcards.langpair.split('-')[1]).to_alpha3()
        shell: '''bash pipeline/opusmt/download-model.sh \
                    "{params.teacher_url}" "{params.teacher_dir}" "{best_model}" {params.src_three_letter} {params.trg_three_letter} >> {log} 2>&1'''
    
elif not forward_pretrained:
    rule train_teacher:
        message: "Training teacher on all data"
        log: f"{log_dir}/train_teacher{{model_index}}-{{ens}}.log"
        conda: "envs/base.yml"
        threads: gpus_num*2
        resources: gpu=gpus_num
        input:
            rules.merge_devset.output, train_src=f'{teacher_corpus}.{src}.gz',train_trg=f'{teacher_corpus}.{trg}.gz',
            bin=ancient(trainer), vocab=vocab_path
        output: model=f'{teacher_base_dir}{{model_index}}-{{ens}}/{best_model}'
        params: prefix_train=teacher_corpus, 
                prefix_test=f"{original}/devset", 
                dir=directory(f'{teacher_base_dir}{{model_index}}-{{ens}}'),
                args=get_args("training-teacher-base")
        shell: '''bash pipeline/train/train.sh \
                    teacher train {src} {trg} "{params.prefix_train}" "{params.prefix_test}" "{params.dir}" \
                    "{input.vocab}" "{best_model_metric}" {params.args} >> {log} 2>&1'''


if augment_corpus:
    rule finetune_teacher:
        message: "Finetune teacher on parallel corpus"
        log: f"{log_dir}/finetune_teacher0-{{ens}}.log"
        conda: "envs/base.yml"
        threads: gpus_num * 2
        resources: gpu=gpus_num
        input:
            rules.merge_devset.output, model=f'{teacher_base_dir}0-{{ens}}/{best_model}',
            train_src=clean_corpus_src, train_trg=clean_corpus_trg,
            bin=ancient(trainer), vocab=vocab_path
        output: model=f'{teacher_finetuned_dir}0-{{ens}}/{best_model}'
        params: prefix_train=f"{clean}/corpus", prefix_test=f"{original}/devset", #modified until we implement bicleaner per language pair, this should be the output of merge_corpus
                dir=directory(f'{teacher_finetuned_dir}0-{{ens}}'),
                args=get_args("training-teacher-finetuned")
        shell: '''bash pipeline/train/train.sh \
                    teacher train {src} {trg} "{params.prefix_train}" "{params.prefix_test}" "{params.dir}" \
                    "{input.vocab}" "{best_model_metric}" --pretrained-model "{input.model}" {params.args} >> {log} 2>&1'''

### translation with teacher

checkpoint split_corpus:
    message: "Splitting the corpus to translate"
    log: f"{log_dir}/split_corpus_{{langpair}}.log"
    conda: "envs/base.yml"
    threads: 1
    input: corpus_src=f"{clean_corpus_prefix}.source.langtagged.gz",corpus_trg=f"{clean_corpus_prefix}.target.gz"
    output: output_dir=directory(f"{translated}/{{langpair}}/corpus"), file=f"{translated}/{{langpair}}/corpus/file.00"
    shell: '''bash pipeline/translate/split-corpus.sh \
                {input.corpus_src} {input.corpus_trg} {output.output_dir} {split_length} >> {log} 2>&1'''

if opusmt_teacher:
    teacher_source_file = f'{translated}/{{langpair}}/corpus/file.{{part}}.{{model_index}}.opusmt'
    teacher_target_file = f'{translated}/{{langpair}}/corpus/file.{{part}}.{{model_index}}.opusmt.nbest'
    teacher_mono_source_file = f'{translated}/{{langpair}}/mono_src/file.{{part}}.{{model_index}}.opusmt'
    teacher_mono_target_file = f'{translated}/{{langpair}}/mono_src/file.{{part}}.{{model_index}}.opusmt.out'
    translated_mono_src_extension = "opusmt.out"
    deseg_nbest_file = f'{teacher_target_file}.deseg'
    
    rule opusmt_deseg_translation:
        message: "Desegmenting OPUS-MT model translation"
        log: f"{log_dir}/opusmt_deseg_mono_translation/{{part}}.{{model_index}}.log"
        threads: 1
        wildcard_constraints:
            model_index="\d+"
        input: f'{translated}/mono_src/file.{{part}}.{{model_index}}.opusmt.out'
        output: f'{translated}/mono_src/file.{{part}}.{{model_index}}.out'
        run: 
            with open(input[0], "rt", encoding="utf8") as infile,open(output[0], "wt", encoding="utf8") as outfile:
                for line in infile:
                    deseg_line = line.replace(" ","").replace("▁"," ")
                    outfile.write(deseg_line)

    #This is an optional rule that only applies when OPUS-MT model is used as teacher.
    #Required due to OPUS-MT models not using the integrated SentencePiece in Marian
    rule opusmt_preprocess_corpus:
        message: "Preprocessing source file for OPUS-MT model"
        log: f"{log_dir}/opusmt_preprocess_corpus/{{langpair}}/{{corpus}}.{{part}}.{{model_index}}.log"
        conda: "envs/base.yml"
        threads: 1
        input: 
            file=f'{translated}/{{langpair}}/{{corpus}}/file.{{part}}', 
            teacher_model=f"{teacher_base_dir}{{model_index}}-0/{best_model}",
            spm_encoder=ancient(spm_encoder)
        output: f'{translated}/{{langpair}}/{{corpus}}/file.{{part}}.{{model_index}}.opusmt'
        shell: '''bash pipeline/translate/opusmt-preprocess.sh \
                    {input.file} {input.teacher_model} "source.spm" {input.spm_encoder} {o2m_teacher} "" "" {wildcards.model_index} >> {log} 2>&1'''
    
    rule opusmt_deseg_nbest:
        message: "Desegmenting OPUS-MT model nbest list"
        log: f"{log_dir}/opusmt_deseg_nbest/{{langpair}}/{{part}}.{{model_index}}.log"
        threads: 1
        input: nbest=f"{teacher_source_file}.nbest"
        output: temp(deseg_nbest_file)
        run: 
            with open(input[0], "rt", encoding="utf8") as infile,open(output[0], "wt", encoding="utf8") as outfile:
                for line in infile:
                    line_split = line.split(" ||| ")
                    line_split[1] = line_split[1].replace(" ","").replace("▁"," ")
                    outfile.write(" ||| ".join(line_split))
else:    
    teacher_source_file = f'{translated}/{{langpair}}/corpus/file.{{part}}'
    teacher_target_file = f'{translated}/{{langpair}}/corpus/file.{{part}}.{{model_index}}.nbest'
    teacher_mono_source_file = f'{translated}/{{langpair}}/mono_src/file.{{part}}'
    teacher_mono_target_file = f'{translated}/{{langpair}}/mono_src/file.{{part}}.{{model_index}}.out'
    translated_mono_src_extension = ".out"
    deseg_nbest_file = teacher_target_file

rule translate_corpus:
    message: "Translating corpus with teacher"
    log: f"{log_dir}/translate_corpus/{{langpair}}/{{part}}.{{model_index}}.log"
    conda: "envs/base.yml"
    threads: gpus_num*2
    resources: gpu=gpus_num
    input:
        ancient(decoder),
        file=teacher_source_file,
        vocab=teacher_source_file if opusmt_teacher else vocab_path, #When distilling from an OPUS-MT teacher, there is no need for the vocab to be an input to this rule.
        teacher_models=expand(f"{final_teacher_dir}{{{{model_index}}}}-{{ens}}/{best_model}",ens=ensemble, allow_missing=True)
    output: file=teacher_target_file
    params: args=get_args('decoding-teacher')
    shell: '''bash pipeline/translate/translate-nbest.sh \
                "{input.file}" "{output.file}" "{input.vocab}" "{input.teacher_models}" {params.args} >> {log} 2>&1'''

rule extract_best:
    message: "Extracting best translations for the corpus"
    log: f"{log_dir}/extract_best/{{langpair}}/{{part}}.{{model_index}}.log"
    conda: "envs/base.yml"
    threads: 1
    #group 'translate_corpus'
    input: nbest=deseg_nbest_file, ref=f"{translated}/{{langpair}}/corpus/file.{{part}}.ref"
    output: f"{translated}/{{langpair}}/corpus/file.{{part}}.nbest.{{model_index}}.out"
    shell: 'python pipeline/translate/bestbleu.py -i {input.nbest} -r {input.ref} -m bleu -o {output} >> {log} 2>&1'

model_indices = list(range(len(opusmt_teacher))) if opusmt_teacher else [0]

rule collect_corpus:
    message: "Collecting translated corpus"
    log: f"{log_dir}/collect_corpus_{{langpair}}_{{model_index}}.log"
    conda: "envs/base.yml"
    threads: 4
    #group 'translate_corpus'
    input: lambda wildcards: expand(f"{translated}/{{langpair}}/corpus/file.{{part}}.nbest.{wildcards.model_index}.out", part=find_parts(wildcards, checkpoints.split_corpus), allow_missing=True)
    output: trg_corpus=f'{translated}/{{langpair}}/corpus.{{model_index}}.target.gz'
    params: src_corpus=f'{clean_corpus_prefix}.source.langtagged.gz',
            dir=f'{translated}/{{langpair}}/corpus'
    shell: 'bash pipeline/translate/collect.sh {params.dir} {output} {params.src_corpus} {wildcards.model_index} >> {log} 2>&1'

# mono

checkpoint split_mono_src:
    message: "Splitting monolingual src dataset"
    log: f"{log_dir}/split_mono_src.log"
    conda: "envs/base.yml"
    threads: 1
    input: corpora=f"{clean}/mono.{src}.gz", bin=ancient(deduper)
    output: directory(f'{translated}/mono_src')
    shell: 'bash pipeline/translate/split-mono.sh {input.corpora} {output} {split_length} >> {log} 2>&1'
    
rule translate_mono_src:
    message: "Translating monolingual src dataset with teacher"
    log: f"{log_dir}/translate_mono_src/{{langpair}}/{{part}}.{{model_index}}.log"
    conda: "envs/base.yml"
    threads: gpus_num*2
    wildcard_constraints:
        model_index="\d+"
    resources: gpu=gpus_num
    input:
        file=teacher_mono_source_file,vocab=vocab_path,
        teacher_models=expand(f"{final_teacher_dir}{{{{model_index}}}}-{{ens}}/{best_model}",ens=ensemble, allow_missing=True),
        bin=ancient(decoder)
    output: file=teacher_mono_target_file
    params: args=get_args('decoding-teacher')
    shell: '''bash pipeline/translate/translate.sh "{input.file}" "{output.file}" "{input.vocab}" {input.teacher_models} \
              {params.args} >> {log} 2>&1'''

#If there are no mono src datasets, create dummy output files, since the merge step
#expects translated mono src files (TODO: separate deduping and shuffling from merge script
#to remove the need for this workaround)
if mono_src_datasets is None:
    rule collect_mono_src_dummy:
        message: "Collecting translated mono src dataset (dummy rule, used in case where no mono src datasets)"
        log: f"{log_dir}/collect_mono_src.{{langpair}}.{{model_index}}.log"
        conda: "envs/base.yml"
        threads: 1
        #group 'mono_src'
        params: src_mono=f"{clean}/{{langpair}}/mono.{src}.gz",dir=f'{translated}/{{langpair}}/mono_src'
        output: trg_mono=f'{translated}/{{langpair}}/mono.{{model_index}}.{trg}.gz'
        shell: 'touch {output.trg_mono}  >> {log} 2>&1'
    rule mono_src_dummy:
        message: "Creating mono src dataset (dummy rule, used in case where no mono src datasets)"
        log: f"{log_dir}/create_mono_src.{{langpair}}.log"
        conda: "envs/base.yml"
        threads: 1
        #group 'mono_src'
        params: src_mono=f"{clean}/{{langpair}}/mono.{src}.gz",dir=f'{translated}/{{langpair}}/mono_src'
        output: src_mono=f"{clean}/{{langpair}}/mono.{src}.gz"
        shell: 'touch {output.src_mono} >> {log} 2>&1'
else:
    rule collect_mono_src:
        message: "Collecting translated mono src dataset"
        log: f"{log_dir}/collect_mono_src.{{model_index}}.log"
        conda: "envs/base.yml"
        threads: 4
        wildcard_constraints:
           model_index="\d+"
        #group 'mono_src'
        input:
           lambda wildcards: expand(f'{translated}/mono_src/file.{{part}}.{wildcards.model_index}.out',
               part=find_parts(wildcards, checkpoints.split_mono_src))
        output: f'{translated}/mono.{{model_index}}.{trg}.gz'
        params: src_mono=f"{clean}/mono.{src}.gz",dir=f'{translated}/mono_src'
        shell: 'bash pipeline/translate/collect-mono.sh "{params.dir}" "{output}" "{params.src_mono}" {wildcards.model_index} >> {log} 2>&1'
    
# merge

rule merge_translated:
    message: "Merging translated datasets"
    log: f"{log_dir}/{{langpair}}/merge_translated.log"
    conda: "envs/base.yml"
    threads: 4
    resources: mem_mb=64000
    #group 'mono_src'
    input:
        src1=f"{clean_corpus_prefix}.source.langtagged.gz",
        src2=f"{clean}/{{langpair}}/mono.{src}.gz",
        trg1=lambda wildcards: expand(f"{translated}/{{langpair}}/corpus.{{model_index}}.target.gz",model_index=model_indices, allow_missing=True),
        trg2=lambda wildcards: expand(f"{translated}/{{langpair}}/mono.{{model_index}}.{trg}.gz",model_index=model_indices, allow_missing=True),
        bin=ancient(deduper)
    output: res_src=f'{merged}/{{langpair}}/corpus.source.gz',res_trg=f'{merged}/{{langpair}}/corpus.target.gz'
    params:
        trg1_template=f"{translated}/{{langpair}}/corpus.model_index.target.gz",
        trg2_template=f"{translated}/{{langpair}}/mono.model_index.{trg}.gz"
    shell: '''bash pipeline/translate/merge-corpus.sh \
                "{input.src1}" "{input.src2}" "{params.trg1_template}" "{params.trg2_template}" \
                "{output.res_src}" "{output.res_trg}" {o2m_student} {model_indices} >> {log} 2>&1'''

# train student 

# preprocess source and target when scoring with opusmt model (note that deseg is not required, since
# scoring produces just scores)
if opusmt_backward:
    score_source = f"{merged}/{{langpair}}/corpus.source.opusmt.gz"
    score_target = f"{merged}/{{langpair}}/corpus.target.opusmt.gz"
else:    
    score_source = f"{merged}/{{langpair}}/corpus.source.gz"
    score_target = f"{merged}/{{langpair}}/corpus.target.gz"

#preprocess corpus before scoring, note that since the scoring is done with the
#backward model, source should be segmented with target.spm and vice versa
rule opusmt_preprocess_for_scoring:
    message: "Preprocessing source file for OPUS-MT model"
    log: f"{log_dir}/opusmt_preprocess_corpus/{{langpair}}/preprocess_for_scoring.log"
    conda: "envs/base.yml"
    threads: 1
    resources: mem_mb=64000
    input: 
        res_src=rules.merge_translated.output.res_src,
        res_trg=rules.merge_translated.output.res_trg,
        model=f'{backward_dir}/{best_model}',
        spm_encoder=ancient(spm_encoder)
    output: opusmt_source=f"{merged}/{{langpair}}/corpus.source.opusmt.gz",
            opusmt_target=f"{merged}/{{langpair}}/corpus.target.opusmt.gz"
    params:
            src = lambda wildcards: Language.get(wildcards.langpair.split('-')[0]).to_alpha3()
    shell: '''bash pipeline/translate/opusmt-preprocess.sh \
              {input.res_src} {input.model} "target.spm" {input.spm_encoder} {o2m_teacher} "" "" && \ 
              bash pipeline/translate/opusmt-preprocess.sh \
              {input.res_trg} {input.model} "source.spm" {input.spm_encoder} "" {params.src} {o2m_backward} >> {log} 2>&1'''

rule score:
    message: "Scoring"
    log: f"{log_dir}/score_{{langpair}}.log"
    conda: "envs/base.yml"
    threads: gpus_num*2
    resources: gpu=gpus_num
    input:
        ancient(scorer),
        model=f'{backward_dir}/{best_model}', vocab=backward_vocab,
        src_corpus=score_source, trg_corpus=score_target
    output: f"{filtered}/{{langpair}}/scores.txt"
    params: input_prefix=f'{merged}/corpus'
    shell: '''bash pipeline/cefilter/score.sh \
                "{input.model}" "{input.vocab}" "{input.src_corpus}" "{input.trg_corpus}" "{output}" >> {log} 2>&1'''

rule ce_filter:
    message: "Cross entropy filtering"
    log: f"{log_dir}/ce_filter_{{langpair}}.log"
    conda: "envs/base.yml"
    threads: workflow.cores
    resources: mem_mb=workflow.cores*5000
    input:
        src_corpus=score_source, trg_corpus=score_target,
        scores=rules.score.output
    output: src_corpus=f"{filtered}/{{langpair}}/corpus.source.gz",trg_corpus=f"{filtered}/{{langpair}}/corpus.target.gz"
    params: input_prefix=f'{merged}/{{langpair}}/corpus',output_prefix=f'{filtered}/{{langpair}}/corpus'
    shell: '''bash pipeline/cefilter/ce-filter.sh \
                "{params.input_prefix}" "{params.output_prefix}" "{input.scores}" >> {log} 2>&1'''

rule merge_filtered:
    message: "Merging filtered parallel datasets"
    log: f"{log_dir}/merge_filtered_corpus.log"
    conda: "envs/base.yml"
    threads: workflow.cores
    input:  expand(f"{filtered}/{{langpair}}/corpus.{{lang}}.gz", langpair=langpairs, lang=['source', 'target'])
    output: src=f"{filtered}/corpus.source.gz",trg=f"{filtered}/corpus.target.gz"
    params: prefix_input=f"{filtered}/*/corpus", prefix_output=f"{filtered}/corpus"
    shell: '''cat $(echo {params.prefix_input}.source.gz | tr ' ' '\n' | tr '\n' ' ') > "{params.prefix_output}.source.gz"
    cat $(echo {params.prefix_input}.target.gz | tr ' ' '\n' | tr '\n' ' ') > "{params.prefix_output}.target.gz" '''

rule alignments:
    message: 'Training word alignment and lexical shortlists'
    log: f"{log_dir}/alignments.log"
    conda: "envs/base.yml"
    threads: workflow.cores
    input:
        ancient(spm_encoder), ancient(spm_exporter),
        src_corpus=rules.merge_filtered.output.src,trg_corpus=rules.merge_filtered.output.trg,
        vocab=vocab_path,
        fast_align=ancient(rules.fast_align.output.fast_align), atools=ancient(rules.fast_align.output.atools),
        extract_lex=ancient(rules.extract_lex.output)
    output: alignment=f'{align_dir}/corpus.aln.gz',shortlist=f'{align_dir}/lex.s2t.pruned.gz'
    params: input_prefix=f'{filtered}/corpus'
    shell: '''bash pipeline/alignment/generate-alignment-and-shortlist.sh \
                "{params.input_prefix}" "{input.vocab}" "{align_dir}" {o2m_student} {threads} >> {log} 2>&1'''

rule train_student:
    message: "Training student"
    log: f"{log_dir}/train_student.log"
    conda: "envs/base.yml"
    threads: gpus_num*2
    resources: gpu=gpus_num
    #group 'student'
    input:
        ancient(trainer),
        train_src=rules.merge_filtered.output.src, train_trg=rules.merge_filtered.output.trg,
        alignments=rules.alignments.output.alignment,
        vocab=vocab_path
    output: model=f'{student_dir}/{best_model}'
    params: prefix_train=rules.merge_filtered.params.prefix_output,prefix_test=f"{original}/devset",
            args=get_args("training-student")
    shell: '''bash pipeline/train/train-student.sh \
                "{input.alignments}" student train "source" "target" "{params.prefix_train}" "{params.prefix_test}" \
                "{student_dir}" "{input.vocab}" "{best_model_metric}" {params.args} >> {log} 2>&1'''

if do_train_student_opustrainer:
    ruleorder: train_student_opustrainer > train_student

    rule alignments_langpair:
        message: 'Training word alignments per language pair'
        log: f"{log_dir}/alignments_{{langpair}}_tsv.log"
        conda: "envs/base.yml"
        threads: workflow.cores
        input:
            ancient(spm_encoder), ancient(spm_exporter),
            multiext(f"{filtered}/{{langpair}}/corpus", f".source.gz", f".target.gz"),
            vocab=vocab_path,
            fast_align= (rules.fast_align.output.fast_align), atools=ancient(rules.fast_align.output.atools),
            extract_lex=ancient(rules.extract_lex.output)
        output: alignment=f'{align_dir}/{{langpair}}/corpus.aln'
        params: prefix=f"{filtered}/{{langpair}}/corpus", output_dir=f"{align_dir}/{{langpair}}/"
        shell: '''bash pipeline/alignment/generate-alignment-tsv.sh \
                    "{params.prefix}" "{input.vocab}" "{params.output_dir}" {o2m_student} {threads} >> {log} 2>&1'''

    rule merge_filtered_langpair_tsv:
        message: "Merging filtered parallel datasets per langpair into tsv format"
        log: f"{log_dir}/merge_filtered_{{langpair}}_tsv.log"
        conda: "envs/base.yml"
        threads: workflow.cores
        # group: "clean_corpus"
        input: multiext(f"{filtered}/{{langpair}}/corpus", f".source.gz", f".target.gz"),
                alignments=f"{align_dir}/{{langpair}}/corpus.aln",
                bin=ancient(deduper)
        #input:  expand(f"{filtered}/{{langpair}}/corpus.{{lang}}.gz", langpair=langpairs, lang=['source', 'target'], allow_missing=True),
        output: f"{filtered}/{{langpair}}/corpus.tsv"
        #   params: prefix_input=f"{original}/{{langpair}}/corpus/{{dataset}}"
        params: prefix=f"{filtered}/{{langpair}}/corpus"
        shell: '''bash pipeline/clean/merge-corpus-tsv.sh "{params.prefix}" "source" "{input.alignments}" >> {log} 2>&1''' #TODO: Fix it with variables

    rule merge_devset_langpair_tsv: # Not sure if this is needed
        message: "Merging clean parallel devsets into tsv format"
        log: f"{log_dir}/merge_dev_{{langpair}}_tsv.log"
        conda: "envs/base.yml"
        threads: workflow.cores
        # group: "clean_corpus"
        # NOT WORKING
        input:  expand(f"{original}/{{langpair}}/devset.{{lang}}.gz", langpair=langpairs, lang=['source.langtagged', 'target'], allow_missing=True),
                bin=ancient(deduper)
        output: f"{original}/{{langpair}}/devset.tsv"
        params: prefix=f"{original}/{{langpair}}/devset",
        shell: '''bash pipeline/clean/merge-corpus-tsv.sh "{params.prefix}" "source.langtagged" "" >> {log} 2>&1'''  #TODO: Fix it with variables
    
    rule merge_devset_tsv:
        message: "Merging clean parallel datasets"
        log: f"{log_dir}/merge_devset.log"
        conda: "envs/base.yml"
        threads: workflow.cores
        input:  expand(f"{original}/{{langpair}}/devset.tsv", langpair=langpairs),
                bin=ancient(deduper)
        output: f"{original}/devset.tsv"
        params: prefix_input=f"{original}/*/devset", prefix_output=f"{original}/devset"
        shell: '''cat $(echo {params.prefix_input}.tsv | tr ' ' '\n' | tr '\n' ' ') > "{params.prefix_output}.tsv"'''

    rule train_student_opustrainer:
        message: "Training student with OpusTrainer"
        log: f"{log_dir}/train_student_opustrainer_{student_prefix}.log"
        conda: "envs/base.yml"
        threads: gpus_num*2
        resources: gpu=gpus_num
        #group 'student'
        input:
            ancient(trainer),
            train=expand(f"{filtered}/{{langpair}}/corpus.tsv", langpair=langpairs),
            devset=rules.merge_devset_tsv.output,
            alignments=rules.alignments.output.alignment,
            vocab=vocab_path
        output: model=f'{student_dir}/{best_model}'
        params: args=get_args("training-student") # is this right
        shell: '''bash pipeline/train/train-opustrainer.sh \
                    student "{opustrainer_config}" "{input.devset}" \
                    "{student_dir}" "{input.vocab}" "{input.alignments}" "{best_model_metric}" {params.args} >> {log} 2>&1'''

# quantize

rule finetune_student:
    message: "Fine-tuning student"
    log: f"{log_dir}/finetune_student.log"
    conda: "envs/base.yml"
    threads: gpus_num*2
    resources: gpu=gpus_num
    #group 'student-finetuned'
    input:
        rules.merge_devset.output, ancient(trainer),
        train_src=rules.merge_filtered.output.src, train_trg=rules.merge_filtered.output.trg,
        alignments=rules.alignments.output.alignment, student_model=f'{student_dir}/{best_model}',
        vocab=vocab_path
    output: model=f'{student_finetuned_dir}/{best_model}'
    params: prefix_train=rules.merge_filtered.params.prefix_output,prefix_test=f"{original}/devset",
            args=get_args("training-student-finetuned")
    shell: '''bash pipeline/train/train-student.sh \
                "{input.alignments}" student finetune "source" "target" "{params.prefix_train}" "{params.prefix_test}" \
                "{student_finetuned_dir}" "{input.vocab}" "{best_model_metric}" --pretrained-model "{input.student_model}" {params.args} >> {log} 2>&1'''

rule quantize:
    message: "Quantization"
    log: f"{log_dir}/quantize.log"
    conda: "envs/base.yml"
    threads: 1
    input:
        ancient(bmt_decoder), ancient(bmt_converter),
        shortlist=rules.alignments.output.shortlist, model=rules.finetune_student.output.model,
        vocab=vocab_path, devset=f"{original}/devset.source.gz"
    output: model=f'{speed_dir}/model.intgemm.alphas.bin'
    shell: '''bash pipeline/quantize/quantize.sh \
                "{input.model}" "{input.vocab}" "{input.shortlist}" "{input.devset}" "{speed_dir}" >> {log} 2>&1'''

rule export:
    message: "Exporting models"
    log: f"{log_dir}/export.log"
    conda: "envs/base.yml"
    #group 'export'
    threads: 1
    input:
        model=rules.quantize.output.model,shortlist=rules.alignments.output.shortlist,
        vocab=vocab_path,marian=bmt_converter
    output:
        model=f'{exported_dir}/model.{dirname}.intgemm.alphas.bin.gz',
        shortlist=f'{exported_dir}/lex.50.50.{dirname}.s2t.bin.gz',
        vocab=f'{exported_dir}/vocab.{dirname}.spm.gz'
    shell:
        'bash pipeline/quantize/export.sh "{speed_dir}" "{input.shortlist}" "{input.vocab}" "{exported_dir}" {dirname} >> {log} 2>&1'


### evaluation

rule evaluate:
    message: "Evaluating a model"
    log: f"{log_dir}/eval/eval_{{model}}_{{dataset}}_{{langpair}}.log"
    conda: "envs/base.yml"
    threads: gpus_num * 2
    resources: gpu=gpus_num
    #group '{model}'
    priority: 50
    wildcard_constraints:
        model="[\w-]+"
    input:
        ancient(decoder),
        data_src=expand(f'{eval_data_dir}/{{dataset}}.source.gz', dataset=eval_datasets, langpair=langpairs),
        data_trg=expand(f'{eval_data_dir}/{{dataset}}.target.gz', dataset=eval_datasets, langpair=langpairs),
        models=lambda wildcards: f'{models_dir}/{wildcards.model}/{best_model}'
                                    if wildcards.model != 'teacher-ensemble'
                                    else [f'{final_teacher_dir}0-{ens}/{best_model}' for ens in ensemble]
    output:
        report(f'{eval_res_dir}/{{model}}/{{langpair}}/{{dataset}}.metrics',
            category='evaluation', subcategory='{model}', caption='reports/evaluation.rst')
    params:
        dataset_prefix=f'{eval_data_dir}/{{dataset}}',
        res_prefix=f'{eval_res_dir}/{{model}}/{{langpair}}/{{dataset}}',
        src=lambda wildcards: wildcards.langpair.split('-')[0] if wildcards.model != "backward" else wildcards.langpair.split('-')[1],
        trg=lambda wildcards: wildcards.langpair.split('-')[1] if wildcards.model != "backward" else wildcards.langpair.split('-')[0],
        trg_three_letter=lambda wildcards: Language.get(wildcards.langpair.split('-')[1]).to_alpha3() if wildcards.model != "backward" else Language.get(wildcards.langpair.split('-')[0]).to_alpha3(),
        o2m=lambda wildcards: (
            o2m_teacher if "teacher" in wildcards.model
            else (o2m_backward if "backward" in wildcards.model 
                  else o2m_student if "student" in wildcards.model else "False")
        ),
        decoder_config=lambda wildcards: f'{models_dir}/{wildcards.model}/{best_model}.decoder.yml'
                            if wildcards.model != 'teacher-ensemble'
                            else f'{final_teacher_dir}0-0/{best_model}.decoder.yml'
    shell: '''bash pipeline/eval/eval-gpu.sh  "{params.src}" "{params.trg}" "{params.res_prefix}" "{params.dataset_prefix}" \
             {params.trg_three_letter} "{params.decoder_config}" {wildcards.model} {params.o2m} {input.models} >> {log} 2>&1'''

rule eval_quantized:
    message: "Evaluating quantized student model"
    log: f"{log_dir}/eval_quantized_{{dataset}}_{{langpair}}.log"
    conda: "envs/base.yml"
    #group 'export'
    threads: 1
    priority: 50
    input:
        ancient(bmt_decoder),
        data_src=expand(f'{eval_data_dir}/{{dataset}}.source.gz', dataset=eval_datasets, langpair=langpairs),
        data_trg=expand(f'{eval_data_dir}/{{dataset}}.target.gz', dataset=eval_datasets, langpair=langpairs),
        model=rules.quantize.output.model,
        shortlist=rules.alignments.output.shortlist,
        vocab=vocab_path
    output:
        report(f'{eval_speed_dir}/{{langpair}}/{{dataset}}.metrics', category='evaluation',
            subcategory='quantized', caption='reports/evaluation.rst')
    params:
        dataset_prefix=f'{eval_data_dir}/{{dataset}}', #, dataset=eval_datasets, allow_missing=True),
        res_prefix=f'{eval_speed_dir}/{{langpair}}/{{dataset}}', #, dataset=eval_datasets, allow_missing=True),
        trg_lng=lambda wildcards: wildcards.langpair.split('-')[1],
        trg_three_letter=lambda wildcards: Language.get(wildcards.langpair.split('-')[1]).to_alpha3(), 
        decoder_config='../quantize/decoder.yml',
        o2m=o2m_student
    shell: '''bash pipeline/eval/eval-quantized.sh "{wildcards.langpair}" "{input.model}" "{input.shortlist}" "{params.dataset_prefix}" \
            "{input.vocab}" "{params.res_prefix}" "{params.decoder_config}" "{params.trg_three_letter}" {params.o2m} >> {log} 2>&1'''
