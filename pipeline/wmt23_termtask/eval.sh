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
test_src=$3
test_dict=$4
src=$5
trg=$6
decoder_config=$7
models=$8
res_prefix=$9
args=( "${@:10}" )

mkdir -p "$(basename "${res_prefix}")"

cat "${dev_src}" |
  tee "${res_prefix}.dev.${src}" |
  "${MARIAN}"/marian-decoder \
    -c "${decoder_config}" \
    --quiet \
    --quiet-translation \
    --log "${res_prefix}.log" \
    --models ${models} \
    "${args[@]}" > "${res_prefix}.dev.${trg}"

python pipeline/wmt23_termtask/wmt23_score.py --system_output  "${res_prefix}.dev.${trg}" --output_lang ${trg} --terms ${dev_dict} > ${res_prefix}.score

echo "###### Done: Scoring model with WMT23 term task dev and test"
