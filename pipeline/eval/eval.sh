#!/bin/bash
##
# Evaluate a model.
#

set -x
set -euo pipefail

echo "###### Evaluation of a model"

langpair=$1
res_prefix=${2}
dataset_prefix=${3}
src=$4
trg=$5
trg_langtag=">>${6}<< "
marian=$7
decoder_config=$8
o2m=$9
args=( "${@:10}" )
model_dir=$(dirname $args) # This only works now for one available model per language pair

mkdir -p "$(basename "${res_prefix}")"

echo "### Evaluating dataset: ${dataset_prefix}, pair: ${langpair}, Results prefix: ${res_prefix}"


if [ -s "${dataset_prefix}.${trg}.gz" ]; then
    pigz -dc "${dataset_prefix}.${trg}.gz" > "${res_prefix}.${trg}.ref"
else
    echo "File ${dataset_prefix}.${trg}.gz is empty. We assume that the dataset ${dataset_prefix} does not exist for the language pair ${langpair}. Creating dummy file and exiting the script."
    touch "${res_prefix}.metrics"
    exit 0
fi

# If the model is the best available, we need to check again whether the model is multilingual at the target side

if [ $o2m == "best" ]; then   
    o2m=$(cat ${model_dir}/one2many.txt)  # Read the content of the file
    echo "Model is multilingual to the target side: $o2m"
fi

if [ $o2m == "True" ]; then # If the model is multitarget, add language tag for decoding
  pigz -dc "${dataset_prefix}.${src}.gz" | sed "s/^/${trg_langtag}/" | #Add language tag for decoding
    tee "${res_prefix}.${src}" | 
    "${marian}"/marian-decoder \
      -c "${decoder_config}" \
      --quiet \
      --quiet-translation \
      --log "${res_prefix}.log" \
      "${args[@]}" |
    tee "${res_prefix}.${trg}" |
    sacrebleu "${res_prefix}.${trg}.ref" -d -f text --score-only -l "${langpair}" -m bleu chrf  |
    tee "${res_prefix}.metrics"
else 
  pigz -dc "${dataset_prefix}.${src}.gz" | 
    tee "${res_prefix}.${src}" |
    "${marian}"/marian-decoder \
      -c "${decoder_config}" \
      --quiet \
      --quiet-translation \
      --log "${res_prefix}.log" \
      "${args[@]}" |
    tee "${res_prefix}.${trg}" |
    sacrebleu "${res_prefix}.${trg}.ref" -d -f text --score-only -l "${langpair}" -m bleu chrf  |
    tee "${res_prefix}.metrics"
fi



echo "###### Done: Evaluation of a model"
