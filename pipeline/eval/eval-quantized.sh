#!/bin/bash
##
# Evaluate a quantized model on CPU.
#

set -x
set -euo pipefail

echo "###### Evaluation of a quantized model"

test -v BMT_MARIAN
test -v SRC
test -v TRG

langpair=$1
model_path=$2
shortlist=$3
dataset_prefix=$4
vocab=$5
res_prefix=$6
decoder_config=$7
trg_langtag=$8
o2m_student=$9

cd "$(dirname "${0}")"

bash eval.sh \
      "${langpair}" \
      "${res_prefix}" \
      "${dataset_prefix}" \
      "${SRC}" \
      "${TRG}" \
      "${trg_langtag}" \
      "${BMT_MARIAN}" \
      "${decoder_config}" \
      "${o2m_student} \
      -m "${model_path}" \
      -v "${vocab}" "${vocab}" \
      --shortlist "${shortlist}" false \
      --int8shiftAlphaAll

echo "###### Done: Evaluation of a quantized model"
