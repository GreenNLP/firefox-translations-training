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

res_prefix=$1
dataset_prefix=$2
src=$3
trg=$4
marian_decoder=$5
decoder_config=$6

cd "$(dirname "${0}")"

bash eval.sh \
      "${res_prefix}" \
      "${dataset_prefix}" \
      "${src}" \
      "${trg}" \
      "${marian_decoder}" \
      "${decoder_config}" \
      -w "${WORKSPACE}" \
      --devices ${GPUS} \
