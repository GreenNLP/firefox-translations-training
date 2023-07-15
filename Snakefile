import yaml
import os
import glob

from snakemake.utils import min_version
from pipeline.bicleaner import packs


min_version("6.6.1")

# `include` directive is not supported by Pycharm plugin, moving all rules to one file to enable live checks
# https://github.com/JetBrains-Research/snakecharm/issues/195


### configuration

containerized: 'Ftt.sif'

install_deps = config['deps'] == 'true'
data_root_dir = config.get('root', srcdir("../data"))
cuda_dir = config.get('cuda', os.environ.get("CUDA_INSTALL_ROOT")) 
cudnn_dir = config.get('cudnn', os.environ.get("CUDNN_INSTALL_ROOT"))
rocm_dir = config.get('rocm',os.environ.get("ROCM_PATH"))

gpus_num = config['numgpus']
# marian occupies all GPUs on a machine if `gpus` are not specified
gpus = config['gpus'] if config['gpus'] else ' '.join([str(n) for n in range(int(gpus_num))])
workspace = config['workspace']
marian_cmake = config['mariancmake']
marian_version = config.get('marianversion','marian-dev')

# experiment
src = config['experiment']['src']
trg = config['experiment']['trg']
src_three_letter = config['experiment'].get('src_three_letter')
trg_three_letter = config['experiment'].get('trg_three_letter')
experiment = config['experiment']['name']

mono_max_sent_src = config['experiment'].get('mono-max-sentences-src')
mono_max_sent_trg = config['experiment'].get('mono-max-sentences-trg')
parallel_max_sents = config['experiment'].get('parallel-max-sentences',"inf")



backward_pretrained = config['experiment'].get('backward-model')
backward_pretrained_vocab = config['experiment'].get('backward-vocab')
vocab_pretrained = config['experiment'].get('vocab')
forward_pretrained = config['experiment'].get('forward-model')

train_student = config['experiment'].get('train-student')
quantize_student = config['experiment'].get('quantize-student')

experiment_dir=f"{data_root_dir}/experiments/{src}-{trg}/{experiment}"

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

# wmt23 term task (TODO: generalize this to generic term support)
wmt23_termtask = config['experiment'].get('wmt23_termtask')
# this applies to finetuning teacher with terms, omitting means fine tuning only with term-augmented data
omit_unannotated = ["-omit",""]

# parallelization

ensemble = list(range(config['experiment'].get('teacher-ensemble',0)))

split_length = config['experiment']['split-length']

# logging
log_dir = f"{data_root_dir}/logs/{src}-{trg}/{experiment}"
reports_dir = f"{data_root_dir}/reports/{src}-{trg}/{experiment}"

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
data_dir = f"{data_root_dir}/data/{src}-{trg}/{experiment}"
clean = f"{data_dir}/clean"
biclean = f"{data_dir}/biclean"
cache_dir = f"{data_dir}/cache"
original = f"{data_dir}/original"
translated = f"{data_dir}/translated"
augmented = f"{data_dir}/augmented"
merged = f"{data_dir}/merged"
filtered = f'{data_dir}/filtered'
align_dir = f"{data_dir}/alignment"
teacher_align_dir = f"{data_dir}/teacher_alignment"
term_data_dir = f"{data_dir}/termdata"


# models
models_dir = f"{data_root_dir}/models/{src}-{trg}/{experiment}"
teacher_base_dir = f"{models_dir}/teacher-base"
teacher_finetuned_dir = f"{models_dir}/teacher-finetuned"
student_dir = f"{models_dir}/student"
student_finetuned_dir = f"{models_dir}/student-finetuned"
speed_dir = f"{models_dir}/speed"
exported_dir = f"{models_dir}/exported"
best_model_metric = config['experiment']['best-model']
best_model = f"final.model.npz.best-{best_model_metric}.npz"
backward_dir = f'{models_dir}/backward'
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
eval_data_dir = f"{original}/eval"
eval_res_dir = f"{models_dir}/evaluation"
eval_backward_dir = f'{eval_res_dir}/backward'
eval_student_dir = f'{eval_res_dir}/student'
eval_student_finetuned_dir = f'{eval_res_dir}/student-finetuned'
eval_speed_dir = f'{eval_res_dir}/speed'
eval_teacher_ens_dir = f'{eval_res_dir}/teacher-ensemble'

# set common environment variables
envs = f'''SRC={src} TRG={trg} MARIAN="{marian_dir}" BMT_MARIAN="{bmt_marian_dir}" GPUS="{gpus}" WORKSPACE={workspace} \
BIN="{bin}" CUDA_DIR="{cuda_dir}" CUDNN_DIR="{cudnn_dir}" ROCM_PATH="{rocm_dir}" '''
# CUDA_VISIBLE_DEVICES is used by bicleaner ai. slurm sets this variable
# it can be overriden manually by 'gpus' config setting to split GPUs in local mode
# Note that this will also work with AMD GPUs, they recognize this env variable
envs += f' CUDA_VISIBLE_DEVICES="{gpus}" '

### workflow options
results = []

if train_student:
    results.extend([
        f'{experiment_dir}/config.yml',
        *expand(f'{eval_student_dir}/{{dataset}}.metrics',dataset=eval_datasets)
        ])

if quantize_student:
    results.extend([
        f'{exported_dir}/model.{src}{trg}.intgemm.alphas.bin.gz',
        f'{exported_dir}/lex.50.50.{src}{trg}.s2t.bin.gz',
        f'{exported_dir}/vocab.{src}{trg}.spm.gz',
        *expand(f'{eval_student_finetuned_dir}/{{dataset}}.metrics',dataset=eval_datasets),
        *expand(f'{eval_speed_dir}/{{dataset}}.metrics',dataset=eval_datasets)
    ])

if wmt23_termtask:
    finetune_teacher_with_terms = wmt23_termtask.get('finetune-teacher-with-terms') 
    train_term_teacher = wmt23_termtask.get('train-term-teacher') 
    
    annotation_schemes = wmt23_termtask['annotation-schemes']
    term_ratios = wmt23_termtask['term-ratios']
    sents_per_term_sents = wmt23_termtask['sents-per-term-sents']

    if not (opusmt_teacher or forward_pretrained):
        results.extend(expand(f'{eval_res_dir}/teacher-base0-{{ens}}/wmt23_termtask.score',ens=ensemble))
        results.extend(expand(f'{eval_res_dir}/teacher-base0-{{ens}}/evalsets_terms.score',ens=ensemble))

        if finetune_teacher_with_terms: 
            results.extend(expand(f'{eval_res_dir}/teacher-base-finetuned-term-{{annotation_scheme}}-{{term_ratio}}-{{sents_per_term_sent}}{{omit}}/wmt23_termtask.score',
                annotation_scheme=annotation_schemes,
                term_ratio=term_ratios,
                sents_per_term_sent=sents_per_term_sents,
                omit=omit_unannotated))

            results.extend(expand(f'{eval_res_dir}/teacher-base-finetuned-term-{{annotation_scheme}}-{{term_ratio}}-{{sents_per_term_sent}}{{omit}}/evalsets_terms.score',
                annotation_scheme=annotation_schemes,
                term_ratio=term_ratios,
                sents_per_term_sent=sents_per_term_sents,
                omit=omit_unannotated))

            results.extend(expand(f'{eval_res_dir}/teacher-base-finetuned-term-{{annotation_scheme}}-{{term_ratio}}-{{sents_per_term_sent}}{{omit}}/{{dataset}}.metrics',
                annotation_scheme=annotation_schemes,
                term_ratio=term_ratios,
                sents_per_term_sent=sents_per_term_sents,
                omit=omit_unannotated,
                dataset=eval_datasets))

        if train_term_teacher:
            results.extend(expand(f'{eval_res_dir}/teacher-base-term-{{annotation_scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/wmt23_termtask.score',
                annotation_scheme=annotation_schemes,
                term_ratio=term_ratios,
                sents_per_term_sent=sents_per_term_sents))

            results.extend(expand(f'{eval_res_dir}/teacher-base-term-{{annotation_scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/{{dataset}}.metrics',
                annotation_scheme=annotation_schemes,
                term_ratio=term_ratios,
                sents_per_term_sent=sents_per_term_sents,dataset=eval_datasets))


    if train_student:
        results.extend([f'{eval_student_dir}/wmt23_termtask.score'])
        
        results.extend(expand(f'{eval_student_dir}-term-{{annotation_scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/wmt23_termtask.score',
            annotation_scheme=annotation_schemes,
            term_ratio=term_ratios,
            sents_per_term_sent=sents_per_term_sents))

        results.extend(expand(f'{eval_student_dir}-term-{{annotation_scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/{{dataset}}.metrics',
            annotation_scheme=annotation_schemes,
            term_ratio=term_ratios,
            sents_per_term_sent=sents_per_term_sents,dataset=eval_datasets))
         


#don't evaluate opus mt teachers or pretrained teachers (TODO: fix sp issues with opusmt teacher evaluation)
if not (opusmt_teacher or forward_pretrained):
    results.extend(expand(f'{eval_res_dir}/teacher-base0-{{ens}}/{{dataset}}.metrics',ens=ensemble, dataset=eval_datasets))

if len(ensemble) > 1:
    results.extend(expand(f'{eval_teacher_ens_dir}/{{dataset}}.metrics', dataset=eval_datasets))

if install_deps:
    results.append("/tmp/flags/setup.done")

#three options for backward model: pretrained path, url to opus-mt, or train backward
if backward_pretrained:
    do_train_backward = False
    backward_dir = backward_pretrained
elif opusmt_backward:
    do_train_backward = False 
else:
    # don't evaluate pretrained model
    if train_student:
        results.extend(expand(f'{eval_backward_dir}/{{dataset}}.metrics',dataset=eval_datasets))
        do_train_backward=True
    else:
        do_train_backward=False

# bicleaner


if 'bicleaner' in config['experiment']:
    bicl_default_threshold = config['experiment']['bicleaner']['default-threshold']
    bicl_dataset_thresholds = config['experiment']['bicleaner']['dataset-thresholds']

    bicleaner_type = packs.find(src, trg)
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

if bicleaner_type:
    clean_corpus_prefix = f'{biclean}/corpus'
    teacher_corpus = f'{biclean}/corpus'
    use_bicleaner = True
else:
    clean_corpus_prefix = f'{clean}/corpus'
    teacher_corpus = f'{clean}/corpus'
    use_bicleaner = False

clean_corpus_src = f'{clean_corpus_prefix}.{src}.gz'
clean_corpus_trg = f'{clean_corpus_prefix}.{trg}.gz'


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

def find_annotation_parts(wildcards, checkpoint):
    checkpoint_output = checkpoint.get(**wildcards).output[0]
    return glob_wildcards(os.path.join(checkpoint_output,"file.src.{part,\d+}.gz")).part

def dataset_norm(name: str):
    return name.replace('/','_')

def get_args(section):
    return marian_args.get(section) or ""

### rules

shell.prefix(f"{envs} ")

rule all:
    input: results

wildcard_constraints:
    term_ratio="\d+",
    sents_per_term_sent="\d+"

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

# data downloading
# TODO: Tatoeba data has dev, test and train in same big tar, make a rule producing them all,
# and use snakemake ruleorder to prioritize it over this
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

if use_bicleaner:
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

# augmentation and teacher training

if not vocab_pretrained:
    rule train_vocab:
        message: "Training spm vocab"
        log: f"{log_dir}/train_vocab.log"
        conda: "envs/base.yml"
        threads: 2
        input: bin=ancient(spm_trainer), corpus_src=clean_corpus_src, corpus_trg=clean_corpus_trg
        output: vocab_path
        params: prefix_train=clean_corpus_prefix,prefix_test=f"{original}/devset"
        shell: '''bash pipeline/train/spm-vocab.sh "{input.corpus_src}" "{input.corpus_trg}" "{output}" {spm_sample_size} \
                   {threads} {spm_vocab_size} >> {log} 2>&1'''

if do_train_backward: 
    mono_trg_file = f'{translated}/mono_trg/file.{{part}}'
    deseg_mono_trg_outfile = f'{mono_trg_file}.out'
    
    rule train_backward:
        message: "Training backward model"
        log: f"{log_dir}/train_backward.log"
        conda: "envs/base.yml"
        threads: gpus_num * 2
        resources: gpu=gpus_num
        #group 'backward'
        input:
            rules.merge_devset.output, train_src=clean_corpus_src,train_trg=clean_corpus_trg,
            bin=ancient(trainer), vocab=vocab_path,
        output:  model=f'{backward_dir}/{best_model}'
        params: prefix_train=clean_corpus_prefix,prefix_test=f"{original}/devset",
                args=get_args("training-backward")
        shell: '''bash pipeline/train/train.sh \
                    backward train {trg} {src} "{params.prefix_train}" "{params.prefix_test}" "{backward_dir}" \
                    "{input.vocab}" "{best_model_metric}" {params.args} >> {log} 2>&1'''

elif opusmt_backward:
    mono_trg_file = f'{translated}/mono_trg/file.{{part}}.{{model_index}}.opusmt'
    deseg_mono_trg_outfile = f'{mono_trg_file}.out.deseg'
    
    rule download_opusmt_backward:
        message: "Downloading OPUS-MT backward model"
        log: f"{log_dir}/download_backward.log"
        conda: "envs/base.yml"
        output:  model=f'{backward_dir}/{best_model}',vocab=f'{backward_dir}/vocab.yml', model_dir=directory({backward_dir})
        shell: '''bash pipeline/opusmt/download-model.sh \
                    "{opusmt_backward}" "{backward_dir}" "{best_model}" {trg_three_letter} {src_three_letter} >> {log} 2>&1''' 


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

# Three options for teacher: 1. download opus-mt model, 2. train teacher with pipeline, 3. path to pretrained teacher model
# TODO: make it possible to combine any of the above options, i.e. use opus-mt, train and use 
# pretrained all in the same run. Probably should have a model list where you can define all the 
# models to use, and then prefixes (opusmt_, train_, pretrained_, nllb_ etc.) determine how the models are
# created/used/connected to (in case of e.g. external APIs).
if 'opusmt-teacher' in config['experiment']:
    rule download_teacher_model:
        message: "Downloading OPUS-MT teacher model"
        log: f"{log_dir}/download_teacher{{model_index}}-{{ens}}.log"
        conda: "envs/base.yml"
        threads: 1
        output: model=f'{teacher_base_dir}{{model_index}}-{{ens}}/{best_model}',vocab=f'{teacher_base_dir}{{model_index}}-{{ens}}/vocab.yml', model_dir=directory(f'{teacher_base_dir}{{model_index}}-{{ens}}')
        params: teacher_dir=f'{teacher_base_dir}{{model_index}}-{{ens}}',
                teacher_url=lambda wildcards: opusmt_teacher[int(wildcards.model_index)] 
        shell: '''bash pipeline/opusmt/download-model.sh \
                    "{params.teacher_url}" "{params.teacher_dir}" "{best_model}" {src_three_letter} {trg_three_letter} >> {log} 2>&1'''
elif not forward_pretrained:
    rule train_teacher:
        message: "Training teacher on all data"
        log: f"{log_dir}/train_teacher{{model_index}}-{{ens}}.log"
        conda: "envs/base.yml"
        threads: gpus_num*3
        resources: gpu=gpus_num
        wildcard_constraints:
           model_index="\d+",
           ens="\d+"
        input:
            rules.merge_devset.output, train_src=f'{teacher_corpus}.{src}.gz',train_trg=f'{teacher_corpus}.{trg}.gz',
            bin=ancient(trainer), vocab=vocab_path
        output: model=f'{teacher_base_dir}{{model_index}}-{{ens}}/{best_model}'
        params: prefix_train=teacher_corpus, 
                prefix_test=f"{original}/devset", 
                dir=directory(f'{teacher_base_dir}{{model_index}}-{{ens}}'),
                args=get_args("training-teacher")
        shell: '''bash pipeline/train/train.sh \
                    teacher train {src} {trg} "{params.prefix_train}" "{params.prefix_test}" "{params.dir}" \
                    "{input.vocab}" "{best_model_metric}" {params.args} >> {log} 2>&1'''

    rule finetune_teacher_with_terms:
        message: "Finetune teacher on term annotated corpus"
        log: f"{log_dir}/finetune_teacher-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}{{omit}}.log"
        wildcard_constraints:
            omit="(.{0}|-omit)"
        conda: "envs/base.yml"
        threads: gpus_num * 2
        resources: gpu=gpus_num
        input:
            rules.merge_devset.output, ancient(trainer),
            model=f'{teacher_base_dir}0-0/{best_model}',
            train_src=f"{term_data_dir}/teacher-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/corpus{{omit}}.{src}.gz",
            train_trg=f"{term_data_dir}/teacher-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/corpus{{omit}}.{trg}.gz",
            alignments=f"{term_data_dir}/teacher-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/corpus{{omit}}.aln.gz",
            vocab=vocab_path
        output: model=f'{teacher_base_dir}-finetuned-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}{{omit}}/model.npz'
        params: 
            prefix_train=f"{term_data_dir}/teacher-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/corpus{{omit}}",
            prefix_test=f"{original}/devset",
            args=get_args("finetune-teacher-with-terms"),
            teacher_term_dir=f"{teacher_base_dir}-finetuned-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}{{omit}}"
        shell: '''bash pipeline/train/term-finetune.sh \
                    teacher train {src} {trg} "{params.prefix_train}" "{params.prefix_test}" \
                    "{params.teacher_term_dir}" "{input.vocab}" "{best_model_metric}" --pretrained-model "{input.model}" {params.args} >> {log} 2>&1'''
        #shell: '''bash pipeline/train/train-student.sh \
        #            "{input.alignments}" teacher train {src} {trg} "{params.prefix_train}" "{params.prefix_test}" \
        #            "{params.teacher_term_dir}" "{input.vocab}" "{best_model_metric}" --pretrained-model "{input.model}" {params.args} >> {log} 2>&1'''

    rule teacher_alignments:
        message: 'Training word alignment and lexical shortlists'
        log: f"{log_dir}/alignments.log"
        conda: "envs/base.yml"
        threads: workflow.cores
        input:
            ancient(spm_encoder), ancient(spm_exporter),
            src_corpus=f'{teacher_corpus}.{src}.gz',trg_corpus=f'{teacher_corpus}.{trg}.gz',
            vocab=vocab_path,
            fast_align=ancient(rules.fast_align.output.fast_align), atools=ancient(rules.fast_align.output.atools),
            extract_lex=ancient(rules.extract_lex.output)
        output: alignment=f'{teacher_align_dir}/corpus.aln.gz',shortlist=f'{teacher_align_dir}/lex.s2t.pruned.gz'
        params: input_prefix=teacher_corpus
        shell: '''bash pipeline/alignment/generate-alignment-and-shortlist.sh \
                    "{params.input_prefix}" "{input.vocab}" "{teacher_align_dir}" {threads} >> {log} 2>&1'''

    # This is normal teacher with alignments, NOT needed for term models, but might be useful later.
    # Note that it uses train-student script, but that just adds the guided alignment
    #NOT TESTED YET!
    rule train_teacher_with_alignment:
        message: "Training student"
        log: f"{log_dir}/train_student.log"
        conda: "envs/base.yml"
        threads: gpus_num*3
        resources: gpu=gpus_num
        #group 'student'
        input:
            rules.merge_devset.output, ancient(trainer),
            train_src=f'{teacher_corpus}.{src}.gz',train_trg=f'{teacher_corpus}.{trg}.gz',
            alignments=rules.teacher_alignments.output.alignment,
            vocab=vocab_path
        output: model=f'{teacher_base_dir}-align/{best_model}'
        params: prefix_train=teacher_corpus,prefix_test=f"{original}/devset",
                args=get_args("training-teacher")
        shell: '''bash pipeline/train/train-student.sh \
                    "{input.alignments}" teacher train {src} {trg} "{params.prefix_train}" "{params.prefix_test}" \
                    "{student_dir}" "{input.vocab}" "{best_model_metric}" {params.args} >> {log} 2>&1'''

    rule train_term_teacher:
        message: "Training teacher with term constraints"
        log: f"{log_dir}/train_teacher-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}.log"
        conda: "envs/base.yml"
        threads: gpus_num*3
        resources: gpu=gpus_num
        input:
            rules.merge_devset.output, ancient(trainer),
            train_src=f"{term_data_dir}/teacher-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/corpus.{src}.gz",
            train_trg=f"{term_data_dir}/teacher-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/corpus.{trg}.gz",
            alignments=f"{term_data_dir}/teacher-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/corpus.aln.gz",
            vocab=vocab_path
        output: model=f'{teacher_base_dir}-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/{best_model}'
        params: prefix_train=f"{term_data_dir}/teacher-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/corpus",prefix_test=f"{original}/devset",
                args=get_args("training-term-teacher"),teacher_term_dir=f"{teacher_base_dir}-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}"
        shell: '''bash pipeline/train/train-student.sh \
                    "{input.alignments}" baseteacher train {src} {trg} "{params.prefix_train}" "{params.prefix_test}" \
                    "{params.teacher_term_dir}" "{input.vocab}" "{best_model_metric}" {params.args} >> {log} 2>&1'''


    #TODO: These are copy pasted from the similar rules for student training, because of deadline.
    #Make generic rules for annotation when time for that
    checkpoint split_teacher_corpus_for_annotation:
        message: "Splitting the teacher corpus for term annotation"
        log: f"{log_dir}/split_teacher_corpus_for_annotation.log"
        conda: "envs/base.yml"
        threads: 1
        input:
            train_src=f'{teacher_corpus}.{src}.gz',train_trg=f'{teacher_corpus}.{trg}.gz',
            alignments=rules.teacher_alignments.output.alignment
        output: directory(f"{term_data_dir}/teacher_corpus")
        shell: '''bash pipeline/wmt23_termtask/split-corpus.sh \
                    {input.train_src} {input.train_trg} {input.alignments} {output} {split_length} >> {log} 2>&1'''

    rule annotate_teacher_terms: 
        message: "Annotating corpus with term information"
        log: f"{log_dir}/annotate_teacher_terms/{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}.{{part}}.log"
        conda: "envs/base.yml"
        threads: 7
        resources: gpu=1
        #group 'student'
        input:
            train_src=f"{term_data_dir}/teacher_corpus/file.src.{{part}}.gz",
            train_trg=f"{term_data_dir}/teacher_corpus/file.trg.{{part}}.gz",
            alignments=f"{term_data_dir}/teacher_corpus/file.aln.{{part}}.gz",
            vocab=vocab_path
        output:
            annotated_src=f"{term_data_dir}/teacher-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/annotated.src.{{part}}.gz",
            annotated_trg=f"{term_data_dir}/teacher-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/annotated.trg.{{part}}.gz",
            annotated_alignments=f"{term_data_dir}/teacher-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/annotated.aln.{{part}}.gz"
        shell: '''python 3rd_party/soft-term-constraints/src/softconstraint.py \
                    --source_spm "{input.vocab}" --target_spm "{input.vocab}" --annotation_method {wildcards.scheme} \
                    --term_start_tag augmentsymbol0 --term_end_tag augmentsymbol1 --trans_end_tag augmentsymbol2 \
                    --mask_tag augmentsymbol3 --source_lang "{src}" --target_lang "{trg}" \
                    --source_corpus "{input.train_src}" --target_corpus "{input.train_trg}" \
                    --alignment_file "{input.alignments}" --terms_per_sent_ratio {wildcards.term_ratio} \
                    --sents_per_term_sent {wildcards.sents_per_term_sent}  \
                    --source_output_path "{output.annotated_src}" --target_output_path "{output.annotated_trg}" \
                    --alignment_output_path "{output.annotated_alignments}" >> {log} 2>&1'''


    rule collect_teacher_term_annotations:
        message: "Collecting term-annotated data"
        log: f"{log_dir}/annotate_teacher_terms/{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}.collect.log"
        wildcard_constraints:
            omit="(.{0}|-omit)"
        conda: "envs/base.yml"
        threads: 4
        input:
            src=lambda wildcards: expand(f"{term_data_dir}/teacher-term-{wildcards.scheme}-{wildcards.term_ratio}-{wildcards.sents_per_term_sent}/annotated.src.{{part}}.gz",
                part=find_annotation_parts(wildcards, checkpoints.split_teacher_corpus_for_annotation)),
            trg=lambda wildcards: expand(f"{term_data_dir}/teacher-term-{wildcards.scheme}-{wildcards.term_ratio}-{wildcards.sents_per_term_sent}/annotated.trg.{{part}}.gz",
                part=find_annotation_parts(wildcards, checkpoints.split_teacher_corpus_for_annotation)),
            alignment=lambda wildcards: expand(f"{term_data_dir}/teacher-term-{wildcards.scheme}-{wildcards.term_ratio}-{wildcards.sents_per_term_sent}/annotated.aln.{{part}}.gz",
                part=find_annotation_parts(wildcards, checkpoints.split_teacher_corpus_for_annotation))
        output:
            annotated_src=f"{term_data_dir}/teacher-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/corpus.{src}.gz",
            annotated_trg=f"{term_data_dir}/teacher-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/corpus.{trg}.gz",
            annotated_alignments=f"{term_data_dir}/teacher-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/corpus.aln.gz",
            annotated_omit_src=f"{term_data_dir}/teacher-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/corpus-omit.{src}.gz",
            annotated_omit_trg=f"{term_data_dir}/teacher-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/corpus-omit.{trg}.gz",
            annotated_omit_alignments=f"{term_data_dir}/teacher-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/corpus-omit.aln.gz"
        params:
            src_prefix=f"{term_data_dir}/teacher-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/annotated.src",
            trg_prefix=f"{term_data_dir}/teacher-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/annotated.trg",
            aln_prefix=f"{term_data_dir}/teacher-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/annotated.aln"

        shell: '''bash pipeline/wmt23_termtask/collect.sh "{params.src_prefix}" "{params.trg_prefix}" "{params.aln_prefix}" \
                "{output.annotated_src}" "{output.annotated_trg}" "{output.annotated_alignments}" \
                "{output.annotated_omit_src}" "{output.annotated_omit_trg}" "{output.annotated_omit_alignments}" >> {log} 2>&1'''


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
        params: prefix_train=clean_corpus_prefix, prefix_test=f"{original}/devset",
                dir=directory(f'{teacher_finetuned_dir}0-{{ens}}'),
                args=get_args("training-teacher-finetuned")
        shell: '''bash pipeline/train/train.sh \
                    teacher train {src} {trg} "{params.prefix_train}" "{params.prefix_test}" "{params.dir}" \
                    "{input.vocab}" "{best_model_metric}" --pretrained-model "{input.model}" {params.args} >> {log} 2>&1'''

### translation with teacher

checkpoint split_corpus:
    message: "Splitting the corpus to translate"
    log: f"{log_dir}/split_corpus.log"
    conda: "envs/base.yml"
    threads: 1
    input: corpus_src=clean_corpus_src,corpus_trg=clean_corpus_trg
    output: directory(f"{translated}/corpus")
    shell: '''bash pipeline/translate/split-corpus.sh \
                {input.corpus_src} {input.corpus_trg} {output} {split_length} >> {log} 2>&1'''

if opusmt_teacher:
    teacher_source_file = f'{translated}/corpus/file.{{part}}.{{model_index}}.opusmt'
    teacher_target_file = f'{translated}/corpus/file.{{part}}.{{model_index}}.opusmt.nbest'
    teacher_mono_source_file = f'{translated}/mono_src/file.{{part}}.{{model_index}}.opusmt'
    teacher_mono_target_file = f'{translated}/mono_src/file.{{part}}.{{model_index}}.opusmt.out'
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
        log: f"{log_dir}/opusmt_preprocess_corpus/{{corpus}}.{{part}}.{{model_index}}.log"
        conda: "envs/base.yml"
        threads: 1
        input: 
            file=f'{translated}/{{corpus}}/file.{{part}}', 
            teacher_model=f"{final_teacher_dir}{{model_index}}-0/{best_model}",
            spm_encoder=ancient(spm_encoder)
        output: f'{translated}/{{corpus}}/file.{{part}}.{{model_index}}.opusmt'
        shell: '''bash pipeline/translate/opusmt-preprocess.sh \
                    {input.file} {input.teacher_model} src "source.spm" {input.spm_encoder} {target_language_token} {wildcards.model_index} >> {log} 2>&1'''
    rule opusmt_deseg_nbest:
        message: "Desegmenting OPUS-MT model nbest list"
        log: f"{log_dir}/opusmt_deseg_nbest/{{part}}.{{model_index}}.log"
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
    teacher_source_file = f'{translated}/corpus/file.{{part}}'
    teacher_target_file = f'{translated}/corpus/file.{{part}}.{{model_index}}.nbest'
    teacher_mono_source_file = f'{translated}/mono_src/file.{{part}}'
    teacher_mono_target_file = f'{translated}/mono_src/file.{{part}}.{{model_index}}.out'
    translated_mono_src_extension = ".out"
    deseg_nbest_file = teacher_target_file


     
rule translate_corpus:
    message: "Translating corpus with teacher"
    log: f"{log_dir}/translate_corpus/{{part}}.{{model_index}}.log"
    conda: "envs/base.yml"
    threads: gpus_num*2
    resources: gpu=gpus_num
    input:
        ancient(decoder),
        file=teacher_source_file,
        vocab=vocab_path,
        teacher_models=expand(f"{final_teacher_dir}{{{{model_index}}}}-{{ens}}/{best_model}",ens=ensemble)
    output: file=teacher_target_file
    params: args=get_args('decoding-teacher')
    shell: '''bash pipeline/translate/translate-nbest.sh \
                "{input.file}" "{output.file}" "{input.vocab}" {input.teacher_models} {params.args} >> {log} 2>&1'''

rule extract_best:
    message: "Extracting best translations for the corpus"
    log: f"{log_dir}/extract_best/{{part}}.{{model_index}}.log"
    conda: "envs/base.yml"
    threads: 1
    #group 'translate_corpus'
    input: nbest=deseg_nbest_file, ref=f"{translated}/corpus/file.{{part}}.ref"
    output: f"{translated}/corpus/file.{{part}}.nbest.{{model_index}}.out"
    shell: 'python pipeline/translate/bestbleu.py -i {input.nbest} -r {input.ref} -m bleu -o {output} >> {log} 2>&1'

model_indices = list(range(len(opusmt_teacher))) if opusmt_teacher else [0]

rule collect_corpus:
    message: "Collecting translated corpus"
    log: f"{log_dir}/collect_corpus_{{model_index}}.log"
    conda: "envs/base.yml"
    threads: 4
    #group 'translate_corpus'
    input: lambda wildcards: expand(f"{translated}/corpus/file.{{part}}.nbest.{wildcards.model_index}.out", part=find_parts(wildcards, checkpoints.split_corpus))
    output: trg_corpus=f'{translated}/corpus.{{model_index}}.{trg}.gz'
    params: src_corpus=clean_corpus_src
    shell: 'bash pipeline/translate/collect.sh {translated}/corpus {output} {params.src_corpus} {wildcards.model_index} >> {log} 2>&1'

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
    log: f"{log_dir}/translate_mono_src/{{part}}.{{model_index}}.log"
    conda: "envs/base.yml"
    threads: gpus_num*2
    wildcard_constraints:
        model_index="\d+"
    resources: gpu=gpus_num
    input:
        file=teacher_mono_source_file,vocab=vocab_path,
        teacher_models=expand(f"{final_teacher_dir}{{{{model_index}}}}-{{ens}}/{best_model}",ens=ensemble),
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
        log: f"{log_dir}/collect_mono_src.{{model_index}}.log"
        conda: "envs/base.yml"
        threads: 1
        #group 'mono_src'
        params: src_mono=f"{clean}/mono.{src}.gz",dir=f'{translated}/mono_src'
        output: trg_mono=f'{translated}/mono.{{model_index}}.{trg}.gz'
        shell: 'touch {output.trg_mono}  >> {log} 2>&1'
    rule mono_src_dummy:
        message: "Creating mono src dataset (dummy rule, used in case where no mono src datasets)"
        log: f"{log_dir}/create_mono_src.log"
        conda: "envs/base.yml"
        threads: 1
        #group 'mono_src'
        params: src_mono=f"{clean}/mono.{src}.gz",dir=f'{translated}/mono_src'
        output: src_mono=f"{clean}/mono.{src}.gz"
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
           lambda wildcards: expand(f'{translated}/mono_src/file.{{part}}.{wildcards.model_index}.out',part=find_parts(wildcards, checkpoints.split_mono_src))
        output: f'{translated}/mono.{{model_index}}.{trg}.gz'
        params: src_mono=f"{clean}/mono.{src}.gz",dir=f'{translated}/mono_src'
        shell: 'bash pipeline/translate/collect-mono.sh "{params.dir}" "{output}" "{params.src_mono}" {wildcards.model_index} >> {log} 2>&1'
    
# merge

rule merge_translated:
    message: "Merging translated datasets"
    log: f"{log_dir}/merge_translated.log"
    conda: "envs/base.yml"
    threads: 4
    resources: mem_mb=64000
    #group 'mono_src'
    input:
        src1=clean_corpus_src,
        src2=f"{clean}/mono.{src}.gz",
        trg1=lambda wildcards: expand(f"{translated}/corpus.{{model_index}}.{trg}.gz",model_index=model_indices),
        trg2=lambda wildcards: expand(f"{translated}/mono.{{model_index}}.{trg}.gz",model_index=model_indices),
        bin=ancient(deduper)
    output: res_src=f'{merged}/corpus.{src}.gz',res_trg=f'{merged}/corpus.{trg}.gz'
    params:
        trg1_template=f"{translated}/corpus.model_index.{trg}.gz",
        trg2_template=f"{translated}/mono.model_index.{trg}.gz"
    shell: '''bash pipeline/translate/merge-corpus.sh \
                "{input.src1}" "{input.src2}" "{params.trg1_template}" "{params.trg2_template}" \
                "{output.res_src}" "{output.res_trg}" {model_indices} >> {log} 2>&1'''

# train student 

# preprocess source and target when scoring with opusmt model (note that deseg is not required, since
# scoring produces just scores)
if opusmt_backward:
    score_source = f"{merged}/corpus.{src}.opusmt.gz"
    score_target = f"{merged}/corpus.{trg}.opusmt.gz"
else:    
    score_source = rules.merge_translated.output.res_src
    score_target = rules.merge_translated.output.res_trg

#preprocess corpus before scoring, note that since the scoring is done with the
#backward model, source should be segmented with target.spm and vice versa
rule opusmt_preprocess_for_scoring:
    message: "Preprocessing source file for OPUS-MT model"
    log: f"{log_dir}/opusmt_preprocess_corpus/preprocess_for_scoring.log"
    conda: "envs/base.yml"
    threads: 1
    resources: mem_mb=64000
    input: 
        res_src=rules.merge_translated.output.res_src,
        res_trg=rules.merge_translated.output.res_trg,
        model=f'{backward_dir}/{best_model}',
        spm_encoder=ancient(spm_encoder)
    output: opusmt_source=f"{merged}/corpus.{src}.opusmt.gz",
            opusmt_target=f"{merged}/corpus.{trg}.opusmt.gz"
    shell: '''bash pipeline/translate/opusmt-preprocess.sh \
              {input.res_src} {input.model} src "target.spm" {input.spm_encoder} {target_language_token} && \
              bash pipeline/translate/opusmt-preprocess.sh \
              {input.res_trg} {input.model} trg "source.spm" {input.spm_encoder} {source_language_token} >> {log} 2>&1'''

rule score:
    message: "Scoring"
    log: f"{log_dir}/score.log"
    conda: "envs/base.yml"
    threads: gpus_num*2
    resources: gpu=gpus_num
    input:
        ancient(scorer),
        model=f'{backward_dir}/{best_model}', vocab=backward_vocab,
        src_corpus=score_source, trg_corpus=score_target
    output: f"{filtered}/scores.txt"
    params: input_prefix=f'{merged}/corpus'
    shell: '''bash pipeline/cefilter/score.sh \
                "{input.model}" "{input.vocab}" "{input.src_corpus}" "{input.trg_corpus}" "{output}" >> {log} 2>&1'''

rule ce_filter:
    message: "Cross entropy filtering"
    log: f"{log_dir}/ce_filter.log"
    conda: "envs/base.yml"
    threads: workflow.cores
    resources: mem_mb=workflow.cores*5000
    input:
        src_corpus=rules.merge_translated.output.res_src,trg_corpus=rules.merge_translated.output.res_trg,
        scores=rules.score.output
    output: src_corpus=f"{filtered}/corpus.{src}.gz",trg_corpus=f"{filtered}/corpus.{trg}.gz"
    params: input_prefix=f'{merged}/corpus',output_prefix=f'{filtered}/corpus'
    shell: '''bash pipeline/cefilter/ce-filter.sh \
                "{params.input_prefix}" "{params.output_prefix}" "{input.scores}" >> {log} 2>&1'''

rule alignments:
    message: 'Training word alignment and lexical shortlists'
    log: f"{log_dir}/alignments.log"
    conda: "envs/base.yml"
    threads: workflow.cores
    input:
        ancient(spm_encoder), ancient(spm_exporter),
        src_corpus=rules.ce_filter.output.src_corpus,trg_corpus=rules.ce_filter.output.trg_corpus,
        vocab=vocab_path,
        fast_align=ancient(rules.fast_align.output.fast_align), atools=ancient(rules.fast_align.output.atools),
        extract_lex=ancient(rules.extract_lex.output)
    output: alignment=f'{align_dir}/corpus.aln.gz',shortlist=f'{align_dir}/lex.s2t.pruned.gz'
    params: input_prefix=f'{filtered}/corpus'
    shell: '''bash pipeline/alignment/generate-alignment-and-shortlist.sh \
                "{params.input_prefix}" "{input.vocab}" "{align_dir}" {threads} >> {log} 2>&1'''

rule train_student:
    message: "Training student"
    log: f"{log_dir}/train_student.log"
    conda: "envs/base.yml"
    threads: gpus_num*3
    resources: gpu=gpus_num
    #group 'student'
    input:
        rules.merge_devset.output, ancient(trainer),
        train_src=rules.ce_filter.output.src_corpus, train_trg=rules.ce_filter.output.trg_corpus,
        alignments=rules.alignments.output.alignment,
        vocab=vocab_path
    output: model=f'{student_dir}/{best_model}'
    params: prefix_train=rules.ce_filter.params.output_prefix,prefix_test=f"{original}/devset",
            args=get_args("training-student")
    shell: '''bash pipeline/train/train-student.sh \
                "{input.alignments}" student train {src} {trg} "{params.prefix_train}" "{params.prefix_test}" \
                "{student_dir}" "{input.vocab}" "{best_model_metric}" {params.args} >> {log} 2>&1'''


checkpoint split_corpus_for_annotation:
    message: "Splitting the corpus for term annotation"
    log: f"{log_dir}/split_corpus_for_annotation.log"
    conda: "envs/base.yml"
    threads: 1
    input:
        train_src=rules.ce_filter.output.src_corpus,
        train_trg=rules.ce_filter.output.trg_corpus,
        alignments=rules.alignments.output.alignment
    output: directory(f"{term_data_dir}/corpus")
    shell: '''bash pipeline/wmt23_termtask/split-corpus.sh \
                {input.train_src} {input.train_trg} {input.alignments} {output} {split_length} >> {log} 2>&1'''

rule annotate_terms: 
    message: "Annotating corpus with term information"
    log: f"{log_dir}/annotate_terms/{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}.{{part}}.log"
    conda: "envs/base.yml"
    threads: 7
    resources: gpu=1,mem_mb=128000
    #group 'student'
    input:
        train_src=f"{term_data_dir}/corpus/file.src.{{part}}.gz",
        train_trg=f"{term_data_dir}/corpus/file.trg.{{part}}.gz",
        alignments=f"{term_data_dir}/corpus/file.aln.{{part}}.gz",
        vocab=vocab_path
    output:
        annotated_src=f"{term_data_dir}/student-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/annotated.src.{{part}}.gz",
        annotated_trg=f"{term_data_dir}/student-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/annotated.trg.{{part}}.gz",
        annotated_alignments=f"{term_data_dir}/student-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/annotated.aln.{{part}}.gz"
    shell: '''python 3rd_party/soft-term-constraints/src/softconstraint.py \
                --source_spm "{input.vocab}" --target_spm "{input.vocab}" --annotation_method {wildcards.scheme} \
                --term_start_tag augmentsymbol0 --term_end_tag augmentsymbol1 --trans_end_tag augmentsymbol2 \
                --mask_tag augmentsymbol3 --source_lang "{src}" --target_lang "{trg}" \
                --source_corpus "{input.train_src}" --target_corpus "{input.train_trg}" \
                --alignment_file "{input.alignments}" --terms_per_sent_ratio {wildcards.term_ratio} \
                --sents_per_term_sent {wildcards.sents_per_term_sent}  \
                --source_output_path "{output.annotated_src}" --target_output_path "{output.annotated_trg}" \
                --alignment_output_path "{output.annotated_alignments}" >> {log} 2>&1'''


rule collect_term_annotations:
    message: "Collecting term-annotated data"
    log: f"{log_dir}/annotate_terms/{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}.collect.log"
    conda: "envs/base.yml"
    threads: 4
    input:
        src=lambda wildcards: expand(f"{term_data_dir}/student-term-{wildcards.scheme}-{wildcards.term_ratio}-{wildcards.sents_per_term_sent}/annotated.src.{{part}}.gz",
            part=find_annotation_parts(wildcards, checkpoints.split_corpus_for_annotation)),
        trg=lambda wildcards: expand(f"{term_data_dir}/student-term-{wildcards.scheme}-{wildcards.term_ratio}-{wildcards.sents_per_term_sent}/annotated.trg.{{part}}.gz",
            part=find_annotation_parts(wildcards, checkpoints.split_corpus_for_annotation)),
        alignment=lambda wildcards: expand(f"{term_data_dir}/student-term-{wildcards.scheme}-{wildcards.term_ratio}-{wildcards.sents_per_term_sent}/annotated.aln.{{part}}.gz",
            part=find_annotation_parts(wildcards, checkpoints.split_corpus_for_annotation))
    output:
        annotated_src=f"{term_data_dir}/student-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/corpus.{src}.gz",
        annotated_trg=f"{term_data_dir}/student-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/corpus.{trg}.gz",
        annotated_alignments=f"{term_data_dir}/student-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/corpus.aln.gz"
    params:
        src_prefix=f"{term_data_dir}/student-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/annotated.src",
        trg_prefix=f"{term_data_dir}/student-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/annotated.trg",
        aln_prefix=f"{term_data_dir}/student-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/annotated.aln"

    shell: '''bash pipeline/wmt23_termtask/collect.sh "{params.src_prefix}" "{params.trg_prefix}" "{params.aln_prefix}" \
            "{output.annotated_src}" "{output.annotated_trg}" "{output.annotated_alignments}" >> {log} 2>&1'''

rule train_term_student:
    message: "Training student with term constraints"
    log: f"{log_dir}/train_student-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}.log"
    conda: "envs/base.yml"
    threads: gpus_num*3
    resources: gpu=gpus_num
    #group 'student'
    input:
        rules.merge_devset.output, ancient(trainer),
        train_src=f"{term_data_dir}/student-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/corpus.{src}.gz",
        train_trg=f"{term_data_dir}/student-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/corpus.{trg}.gz",
        alignments=f"{term_data_dir}/student-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/corpus.aln.gz",
        vocab=vocab_path
    output: model=f'{student_dir}-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/{best_model}'
    params: prefix_train=f"{term_data_dir}/student-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/corpus",prefix_test=f"{original}/devset",
            args=get_args("training-student"),student_term_dir=f"{student_dir}-term-{{scheme}}-{{term_ratio}}-{{sents_per_term_sent}}"
    shell: '''bash pipeline/train/train-student.sh \
                "{input.alignments}" student train {src} {trg} "{params.prefix_train}" "{params.prefix_test}" \
                "{params.student_term_dir}" "{input.vocab}" "{best_model_metric}" {params.args} >> {log} 2>&1'''

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
        train_src=rules.ce_filter.output.src_corpus, train_trg=rules.ce_filter.output.trg_corpus,
        alignments=rules.alignments.output.alignment, student_model=rules.train_student.output.model,
        vocab=vocab_path
    output: model=f'{student_finetuned_dir}/{best_model}'
    params: prefix_train=rules.ce_filter.params.output_prefix,prefix_test=f"{original}/devset",
            args=get_args("training-student-finetuned")
    shell: '''bash pipeline/train/train-student.sh \
                "{input.alignments}" student finetune {src} {trg} "{params.prefix_train}" "{params.prefix_test}" \
                "{student_finetuned_dir}" "{input.vocab}" "{best_model_metric}" --pretrained-model "{input.student_model}" {params.args} >> {log} 2>&1'''

rule quantize:
    message: "Quantization"
    log: f"{log_dir}/quantize.log"
    conda: "envs/base.yml"
    threads: 1
    input:
        ancient(bmt_decoder), ancient(bmt_converter),
        shortlist=rules.alignments.output.shortlist, model=rules.finetune_student.output.model,
        vocab=vocab_path, devset=f"{original}/devset.{src}.gz"
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
        model=f'{exported_dir}/model.{src}{trg}.intgemm.alphas.bin.gz',
        shortlist=f'{exported_dir}/lex.50.50.{src}{trg}.s2t.bin.gz',
        vocab=f'{exported_dir}/vocab.{src}{trg}.spm.gz'
    shell:
        'bash pipeline/quantize/export.sh "{speed_dir}" "{input.shortlist}" "{input.vocab}" "{exported_dir}" >> {log} 2>&1'


### evaluation

rule evaluate:
    message: "Evaluating a model"
    log: f"{log_dir}/eval/eval_{{model}}_{{dataset}}.log"
    conda: "envs/base.yml"
    threads: gpus_num * 2
    resources: gpu=gpus_num
    #group '{model}'
    priority: 50
    wildcard_constraints:
        model="[\w-]+"
    input:
        ancient(decoder),
        data=multiext(f'{eval_data_dir}/{{dataset}}',f".{src}.gz",f".{trg}.gz"),
        vocab=vocab_path,
        models=lambda wildcards: f'{models_dir}/{wildcards.model}/model.npz'
                                    if "finetuned-term" in wildcards.model
                                    else f'{models_dir}/{wildcards.model}/{best_model}'
                                    #TODO: handle ensembling better
                                    #if wildcards.model != 'teacher-ensemble'
                                    #else [f'{final_teacher_dir}0-{ens}/{best_model}' for ens in ensemble]
    output:
        report(f'{eval_res_dir}/{{model}}/{{dataset}}.metrics',
            category='evaluation', subcategory='{model}', caption='reports/evaluation.rst')
    params:
        dataset_prefix=f'{eval_data_dir}/{{dataset}}',
        res_prefix=f'{eval_res_dir}/{{model}}/{{dataset}}',
        src_lng=lambda wildcards: src if wildcards.model != 'backward' else trg,
        trg_lng=lambda wildcards: trg if wildcards.model != 'backward' else src,
        decoder_config=lambda wildcards: f'{models_dir}/{wildcards.model}/{best_model}.decoder.yml'
                            if wildcards.model != 'teacher-ensemble'
                            else f'{final_teacher_dir}0-0/{best_model}.decoder.yml'
    shell: '''bash pipeline/eval/eval-gpu.sh "{params.res_prefix}" "{params.dataset_prefix}" \
             {params.src_lng} {params.trg_lng} "{params.decoder_config}" {input.vocab} {input.models} >> {log} 2>&1'''

rule eval_quantized:
    message: "Evaluating qunatized student model"
    log: f"{log_dir}/eval_quantized_{{dataset}}.log"
    conda: "envs/base.yml"
    #group 'export'
    threads: 1
    priority: 50
    input:
        ancient(bmt_decoder),
        data=multiext(f'{eval_data_dir}/{{dataset}}',f".{src}.gz",f".{trg}.gz"),
        model=rules.quantize.output.model,
        shortlist=rules.alignments.output.shortlist,
        vocab=vocab_path
    output:
        report(f'{eval_speed_dir}/{{dataset}}.metrics', category='evaluation',
            subcategory='quantized', caption='reports/evaluation.rst')
    params:
        dataset_prefix=f'{eval_data_dir}/{{dataset}}',
        res_prefix=f'{eval_speed_dir}/{{dataset}}',
        decoder_config='../quantize/decoder.yml'
    shell: '''bash pipeline/eval/eval-quantized.sh "{input.model}" "{input.shortlist}" "{params.dataset_prefix}" \
            "{input.vocab}" "{params.res_prefix}" "{params.decoder_config}" >> {log} 2>&1'''

rule annotate_evalsets: 
    message: "Annotating evalsets with term information"
    log: f"{log_dir}/annotate_evalset.log"
    conda: "envs/base.yml"
    threads: workflow.cores
    #This should run on CPU, there are not that many sentences usually. If using a big evalset, uncomment this.
    #resources: gpu=1,mem_mb=128000
    #group 'student'
    input:
        evalsets_aln=f'{eval_data_dir}/evalsets.aln.gz',
        evalsets_src=f'{eval_data_dir}/evalsets.src.gz',
        evalsets_trg=f'{eval_data_dir}/evalsets.trg.gz',
        vocab=vocab_path
    output:
        evalsets_terms_src=f'{eval_data_dir}/evalsets_terms.src',
        evalsets_terms_trg=f'{eval_data_dir}/evalsets_terms.trg',
        evalsets_terms_aln=f'{eval_data_dir}/evalsets_terms.aln',
        evalsets_terms_jsonl=f'{eval_data_dir}/evalsets_terms.jsonl'
    params: 
        evalsets_terms_src_gz=f'{eval_data_dir}/evalsets_terms.src.gz',
        evalsets_terms_trg_gz=f'{eval_data_dir}/evalsets_terms.trg.gz',
        evalsets_terms_aln_gz=f'{eval_data_dir}/evalsets_terms.aln.gz',
    shell: '''python 3rd_party/soft-term-constraints/src/softconstraint.py \
                --source_spm "{input.vocab}" --target_spm "{input.vocab}"  \
                --term_start_tag augmentsymbol0 --term_end_tag augmentsymbol1 --trans_end_tag augmentsymbol2 \
                --mask_tag augmentsymbol3 --source_lang "{src}" --target_lang "{trg}" \
                --source_corpus "{input.evalsets_src}" --target_corpus "{input.evalsets_trg}" \
                --alignment_file "{input.evalsets_aln}" --do_not_augment --omit_unannotated  \
                --source_output_path "{params.evalsets_terms_src_gz}" --target_output_path "{params.evalsets_terms_trg_gz}" \
                --alignment_output_path "{params.evalsets_terms_aln_gz}" --term_jsonl_output_path "{output.evalsets_terms_jsonl}" \
                && zcat "{params.evalsets_terms_src_gz}" > "{output.evalsets_terms_src}" \
                && zcat "{params.evalsets_terms_trg_gz}" > "{output.evalsets_terms_trg}" \
                && zcat "{params.evalsets_terms_aln_gz}" > "{output.evalsets_terms_aln}" >> {log} 2>&1'''

rule eval_termscore: 
    message: "Scoring evalsets based on recognized terms"
    log: f"{log_dir}/eval/eval_{{model}}_termscore.log"
    conda: "envs/base.yml"
    threads: 8
    resources: gpu=1
    #group '{model}'
    priority: 50
    wildcard_constraints:
        model="[\w-]+"
    input:
        ancient(decoder),
        eval_src=rules.annotate_evalsets.output.evalsets_terms_src,
        eval_trg=rules.annotate_evalsets.output.evalsets_terms_trg,
        eval_dict=rules.annotate_evalsets.output.evalsets_terms_jsonl,
        vocab=vocab_path, 
        models=lambda wildcards: f'{models_dir}/{wildcards.model}/model.npz'
                                    if "finetuned-term" in wildcards.model
                                    else f'{models_dir}/{wildcards.model}/{best_model}'
                                    #TODO: handle ensembling better
                                    #if wildcards.model != 'teacher-ensemble'
                                    #else [f'{final_teacher_dir}0-{ens}/{best_model}' for ens in ensemble]
    output: f'{eval_res_dir}/{{model}}/evalsets_terms.score'
    params:
        res_prefix=f'{eval_res_dir}/{{model}}/evalsets_terms',
        decoder_config=lambda wildcards: f'{models_dir}/{wildcards.model}/{best_model}.decoder.yml'
                            if wildcards.model != 'teacher-ensemble'
                            else f'{final_teacher_dir}0-0/{best_model}.decoder.yml'
    shell: '''bash pipeline/wmt23_termtask/eval.sh "{input.eval_src}" "{input.eval_dict}" "{src}" "{trg}" \
            "{params.decoder_config}" {input.models} {input.vocab} {params.res_prefix} >> {log} 2>&1'''

rule align_evalsets:
    message: 'Training word alignment for evalsets'
    log: f"{log_dir}/evalset_alignments.log"
    conda: "envs/base.yml"
    threads: workflow.cores
    input:
        ancient(spm_encoder), ancient(spm_exporter),
        evalset_src=expand(f"{eval_data_dir}/{{dataset}}.{src}.gz",dataset=eval_datasets),
        evalset_trg=expand(f"{eval_data_dir}/{{dataset}}.{trg}.gz",dataset=eval_datasets),
        src_corpus=f'{teacher_corpus}.{src}.gz',trg_corpus=f'{teacher_corpus}.{trg}.gz',
        vocab=vocab_path,
        fast_align=ancient(rules.fast_align.output.fast_align), atools=ancient(rules.fast_align.output.atools),
        extract_lex=ancient(rules.extract_lex.output)
    output:
        evalsets_aln=f'{eval_data_dir}/evalsets.aln.gz',
        evalsets_src=f'{eval_data_dir}/evalsets.src.gz',
        evalsets_trg=f'{eval_data_dir}/evalsets.trg.gz'
    params: output_dir=eval_data_dir 
    shell: '''bash -c \'cat {input.evalset_src} > {output.evalsets_src} && \
             cat {input.evalset_trg} > {output.evalsets_trg} && \
             bash pipeline/eval/generate-alignment.sh \
                    "{output.evalsets_src}" "{output.evalsets_trg}" "{input.src_corpus}" "{input.trg_corpus}" "{input.vocab}" "{params.output_dir}" {threads} >> {log} 2>&1\''''

rule wmt23_termtask_score: 
    message: "Scoring wmt23 termtask dev data"
    log: f"{log_dir}/eval/eval_{{model}}_wmt23_termtask.log"
    conda: "envs/base.yml"
    threads: 8
    resources: gpu=1
    #group '{model}'
    priority: 50
    wildcard_constraints:
        model="[\w-]+"
    input:
        ancient(decoder),
        wmt23_dev_src=f"{data_root_dir}/wmt23_term_devtest/dev/dev.{src}-{trg}.{src}",
        wmt23_dev_dict=f"{data_root_dir}/wmt23_term_devtest/dev/dev.{src}-{trg}.dict.jsonl",
        wmt23_test_src=f"{data_root_dir}/wmt23_term_devtest/test/test.{src}-{trg}.{src}",
        wmt23_test_dict=f"{data_root_dir}/wmt23_term_devtest/test/test.{src}-{trg}.dict.jsonl",
        vocab=vocab_path, 
        models=lambda wildcards: f'{models_dir}/{wildcards.model}/model.npz'
                                    if "finetuned-term" in wildcards.model
                                    else f'{models_dir}/{wildcards.model}/{best_model}'
                                    #TODO: handle ensembling better
                                    #if wildcards.model != 'teacher-ensemble'
                                    #else [f'{final_teacher_dir}0-{ens}/{best_model}' for ens in ensemble]
    output: f'{eval_res_dir}/{{model}}/wmt23_termtask.score'
    params:
        res_prefix=f'{eval_res_dir}/{{model}}/wmt23_termtask',
        decoder_config=lambda wildcards: f'{models_dir}/{wildcards.model}/{best_model}.decoder.yml'
                            if wildcards.model != 'teacher-ensemble'
                            else f'{final_teacher_dir}0-0/{best_model}.decoder.yml'
    shell: '''bash pipeline/wmt23_termtask/eval.sh "{input.wmt23_dev_src}" "{input.wmt23_dev_dict}" "{src}" "{trg}" \
            "{params.decoder_config}" {input.models} {input.vocab} {params.res_prefix} >> {log} 2>&1'''

