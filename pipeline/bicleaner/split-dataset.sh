#!/bin/bash
##
# Splits a parallel dataset
#

set -x
set -euo pipefail

COMPRESSION_CMD="${COMPRESSION_CMD:-pigz}"
ARTIFACT_EXT="${ARTIFACT_EXT:-gz}"

corpus_src=$1
corpus_trg=$2
output_dir=$3
length=$4
corpus_pasted="${output_dir}/corpus.pasted.${ARTIFACT_EXT}"

mkdir -p "${output_dir}"

paste <(${COMPRESSION_CMD} -dc "${corpus_src}") <(${COMPRESSION_CMD} -dc "${corpus_trg}") | split -d -l ${length} - "${output_dir}/file."

pigz ${output_dir}/*
