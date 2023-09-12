#!/bin/bash
##
# Evaluate a model on GPU.
#

set -x
set -euo pipefail

echo "###### Evaluation of a model"

test -v GPUS
test -v MARIAN
test -v WORKSPACE
test -v SRC
test -v TRG

langpair=$1
res_prefix=$2
dataset_prefix=$3
trg_langtag=$4
decoder_config=$5
o2m_student=$6
models=( "${@:7}" )

cd "$(dirname "${0}")"

bash eval.sh \
      "${langpair}" \
      "${res_prefix}" \
      "${dataset_prefix}" \
      "${SRC}" \
      "${TRG}" \
      "${trg_langtag}" \
      "${MARIAN}" \
      "${decoder_config}" \
      "${o2m_student}" \
      -w "${WORKSPACE}" \
      --devices ${GPUS} \
      -m "${models[@]}"