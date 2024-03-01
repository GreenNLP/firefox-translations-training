#!/bin/bash
##
# Score model against wmt23 termtask dev and test.
#

set -x
set -euo pipefail

# On LUMI, having CUDA_VISIBLE_DEVICES set causes a segfault when using multiple GPUs
unset CUDA_VISIBLE_DEVICES


eval_src=$1
src=$2
trg=$3
decoder_config=$4
models=$5
vocab=$6
res_prefix=$7
args=( "${@:8}" )

mkdir -p "$(basename "${res_prefix}")"

# Check whether this is a term model
model_base_dir=$(basename $(dirname ${models}))
term_model_regex="^.*term-([a-z-]+)-[0-9]+-[0-9]+"
if [[ $model_base_dir =~ $term_model_regex ]]; then
  cat "${eval_src}" |
  tee "${res_prefix}.eval.${src}" |
    "${MARIAN}"/marian-decoder \
      -c "${decoder_config}" \
      --quiet \
      --quiet-translation \
      --log "${res_prefix}.log" \
      --models ${models} \
      --vocabs "${vocab}" "${vocab}" \
      "${args[@]}" > "${res_prefix}.eval.${trg}"
else
  #TODO: change the augmentation scheme in the previous step to append, change this to remove the augmentsymbols
  #and lemma keep source surface
  cat "${eval_src}" | sed -r "s/ ?augmentsymbol[0-9] ?/ /g" |
  tee "${res_prefix}.eval.${src}" |
    "${MARIAN}"/marian-decoder \
      -c "${decoder_config}" \
      --quiet \
      --quiet-translation \
      --log "${res_prefix}.log" \
      --models ${models} \
      --vocabs "${vocab}" "${vocab}" \
      "${args[@]}" > "${res_prefix}.eval.${trg}"
fi

echo "###### Done: Scoring model with WMT23 term task dev and test"
