#!/bin/bash
##
# Score model against wmt23 termtask dev and test.
#

set -x
set -euo pipefail

# On LUMI, having CUDA_VISIBLE_DEVICES set causes a segfault when using multiple GPUs
unset CUDA_VISIBLE_DEVICES

echo "###### Scoring a model with WMT23 term task dev and test"

dev_src=$1
dev_dict=$2
src=$3
trg=$4
decoder_config=$5
models=$6
vocab=$7
res_prefix=$8
args=( "${@:9}" )

# Check whether this is a term model 
model_base_dir=$(basename $(dirname ${models}))
term_model_regex="^.*term-([a-z-]+)-[0-9]+-[0-9]+"
if [[ $model_base_dir =~ $term_model_regex ]]; then
  echo "###### Annotating terms to input file"
  annotation_scheme="${BASH_REMATCH[1]}"
  # Add term augmentation annotations to test set
  annotated_dev_src=${dev_src}.${annotation_scheme}
  python 3rd_party/soft-term-constraints/src/annotate.py --source_file ${dev_src} --source_lang ${src} --target_lang ${trg} --terms_per_sentence ${dev_dict} --source_output_path ${annotated_dev_src} --term_start_tag augmentsymbol0 --term_end_tag augmentsymbol1 --trans_end_tag augmentsymbol2
  dev_src=${annotated_dev_src}
fi



mkdir -p "$(basename "${res_prefix}")"

cat "${dev_src}" |
  tee "${res_prefix}.dev.${src}" |
  "${MARIAN}"/marian-decoder \
    -c "${decoder_config}" \
    --quiet \
    --quiet-translation \
    --log "${res_prefix}.log" \
    --models ${models} \
    --vocabs "${vocab}" "${vocab}" \
    "${args[@]}" > "${res_prefix}.dev.${trg}"

python pipeline/wmt23_termtask/wmt23_score.py --system_output  "${res_prefix}.${trg}" --output_lang ${trg} --terms ${dev_dict} > ${res_prefix}.score

echo "###### Done: Scoring model with WMT23 term task dev and test"
