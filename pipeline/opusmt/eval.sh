#!/bin/bash
##
# Evaluate a model on GPU.
#

set -x
set -euo pipefail

echo "###### Evaluation of a model"

# On LUMI, having CUDA_VISIBLE_DEVICES set causes a segfault when using multiple GPUs
unset CUDA_VISIBLE_DEVICES

test -v GPUS
test -v MARIAN
test -v WORKSPACE

marian=$MARIAN

res_prefix=$1
dataset_prefix=$2
src=$3
trg=$4
src_spm=$5
trg_spm=$6
vocab=$7
decoder_config=$8
models=( "${@:9}" )

mkdir -p "$(basename "${res_prefix}")"

echo "### Evaluating dataset: ${dataset_prefix}, pair: ${src}-${trg}, Results prefix: ${res_prefix}"

pigz -dc "${dataset_prefix}.${trg}.gz" > "${res_prefix}.${trg}.ref"

pigz -dc "${dataset_prefix}.${src}.gz" | ${marian}/spm_encode --model ${src_spm} |
  tee "${res_prefix}.spm.${src}" |
  "${marian}"/marian-decoder \
    -c "${decoder_config}" \
    --quiet \
    --quiet-translation \
    --log "${res_prefix}.log" \
    -w "${WORKSPACE}" \
    --devices ${GPUS} \
    -m "${models[@]}" \
    --vocabs ${vocab} ${vocab} |
  ${marian}/spm_decode --model ${trg_spm} | tee "${res_prefix}.${trg}" |
  sacrebleu "${res_prefix}.${trg}.ref" -d -f text --score-only -l "${src}-${trg}" -m bleu chrf  |
  tee "${res_prefix}.metrics"

echo "###### Done: Evaluation of a model"
