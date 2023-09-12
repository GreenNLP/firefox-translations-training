#!/bin/bash
##
# Evaluate a model.
#

set -x
set -euo pipefail

echo "###### Evaluation of a model"

langpair=$1
res_prefix="${2}.${langpair}"
dataset_prefix="${3}.${langpair}"
src=$4
trg=$5
trg_langtag=">>${6}<< "
marian=$7
decoder_config=$8
args=( "${@:9}" )

mkdir -p "$(basename "${res_prefix}")"

echo "### Evaluating dataset: ${dataset_prefix}, pair: ${langpair}, Results prefix: ${res_prefix}"

pigz -dc "${dataset_prefix}.${trg}.gz" > "${res_prefix}.${trg}.ref"

pigz -dc "${dataset_prefix}.${src}.gz" | sed "s/^/${trg_langtag}/" | #Add language tag for decoding
  tee "${res_prefix}.${src}" | 
  "${marian}"/marian-decoder \
    -c "${decoder_config}" \
    --quiet \
    --quiet-translation \
    --log "${res_prefix}.log" \
    "${args[@]}" |
  tee "${res_prefix}.${trg}" |
  sacrebleu "${res_prefix}.${trg}.ref" -d -f text --score-only -l "${src}-${trg}" -m bleu chrf  |
  tee "${res_prefix}.metrics"

echo "###### Done: Evaluation of a model"
