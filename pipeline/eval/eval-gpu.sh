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
test -v SRC
test -v TRG

src=$1
trg=$2
res_prefix=$3
dataset_prefix=$4
trg_langtag=$5
decoder_config=$6
model_type=$7
o2m=$8
models=( "${@:9}" )

langpair="${src}-${trg}"


cd "$(dirname "${0}")"

if [[ $model_type == "backward" ]]; then
      bash eval.sh \
            "${langpair}" \
            "${res_prefix}" \
            "${dataset_prefix}" \
            "${TRG}" \
            "${SRC}" \
            "${trg_langtag}" \
            "${MARIAN}" \
            "${decoder_config}" \
            "${o2m}" \
            -w "${WORKSPACE}" \
            --devices ${GPUS} \
            -m "${models[@]}"
else
      bash eval.sh \
            "${langpair}" \
            "${res_prefix}" \
            "${dataset_prefix}" \
            "${SRC}" \
            "${TRG}" \
            "${trg_langtag}" \
            "${MARIAN}" \
            "${decoder_config}" \
            "${o2m}" \
            -w "${WORKSPACE}" \
            --devices ${GPUS} \
            -m "${models[@]}"
fi
