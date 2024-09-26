#!/bin/bash
##
# Evaluate a model using ctranslate2.
#

set -x
set -euo pipefail

echo "###### Evaluation of a model with ctranslate2"

res_prefix=$1
dataset_prefix=$2
src=$3
trg=$4
ct2_model_dir=$5
sp_model=$6
threads=$7
batch_size=$8
args=( "${@:9}" )

mkdir -p "$(basename "${res_prefix}")"

echo "### Evaluating dataset: ${dataset_prefix}, pair: ${src}-${trg}, Results prefix: ${res_prefix}"

pigz -dc "${dataset_prefix}.${trg}.gz" > "${res_prefix}.${trg}.ref"
pigz -dc "${dataset_prefix}.${src}.gz" > "${res_prefix}.${src}"


python pipeline/eval/ct2_translate.py \
    --model_directory "${ct2_model_dir}" \
    --input_file "${res_prefix}.${src}" \
    --sentencepiece_model "${sp_model}" \
    --threads "${threads}" \
    --batch_size "${batch_size}" | tee "${res_prefix}.${trg}" |
  sacrebleu "${res_prefix}.${trg}.ref" -d -f text --score-only -l "${src}-${trg}" -m bleu chrf  |
  tee "${res_prefix}.ct2.metrics"

echo "###### Done: Evaluation of a model"