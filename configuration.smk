
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
train_datasets = config['datasets'].get('train')
tc_scored = config['datasets'].get('tc_scored')
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
    marian_dir = f'{third_party_dir}/lumi-marian/build'
else:
    marian_dir = f'{third_party_dir}/marian-dev/build'
    
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
biclean_scored = f"{data_dir}/biclean_scored"
simple_rat = f"{data_dir}/simple_rat"
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


from pipeline.bicleaner import packs
if 'bicleaner' in config['experiment']: 
    bicleaner_type = packs.find(src, trg)
else:
    bicleaner_type = None

# bicleaner
if bicleaner_type:
    clean_corpus_prefix = f'{biclean}/corpus'
    teacher_corpus = f'{biclean}/corpus'
elif tc_scored:
    clean_corpus_prefix = f'{biclean_scored}/corpus'
    teacher_corpus = f'{teacher_align_dir}/corpus.spm'
else:
    clean_corpus_prefix = f'{clean}/corpus'
    teacher_corpus = f'{clean}/corpus'

clean_corpus_src = f'{clean_corpus_prefix}.{src}.gz'
clean_corpus_trg = f'{clean_corpus_prefix}.{trg}.gz'

