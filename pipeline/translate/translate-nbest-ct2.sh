#!/bin/bash
##
# Translates files generating n-best lists as output
#

set -x
set -euo pipefail

#test -v GPUS
#test -v MARIAN
#test -v WORKSPACE

# On LUMI, having CUDA_VISIBLE_DEVICES set causes a segfault when using multiple GPUs
unset CUDA_VISIBLE_DEVICES

input=$1
output=$2
sp_model=$3
ct2_model_dir=$(dirname ${4})

# this needs to be larger than 1 only for CPU decoding, for GPU parallelism, provide device indices to Translator (not yet implemented)
threads=1

beam_size=8
num_hypotheses=8
compute_type=float16

#batch size is in tokens, this is the Tesla V100 batch size used in https://aclanthology.org/2020.ngt-1.25.pdf
batch_size=6000

cd "$(dirname "${0}")"

python ../eval/ct2_translate.py \
    --model_directory "${ct2_model_dir}" \
    --input_file "${input}" \
    --sentencepiece_model "${sp_model}" \
    --threads "${threads}" \
    --batch_size "${batch_size}" \
    --beam_size "${beam_size}" \
    --num_hypotheses "${num_hypotheses}" \
    --output_file "${output}" \
    --compute_type "${compute_type}"

test "$(wc -l <"${output}")" -eq "$(( $(wc -l <"${input}") * 8 ))"
