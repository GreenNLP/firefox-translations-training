#!/bin/bash
##
# Downloads corpus using sacrebleu
#

set -x
set -euo pipefail

echo "###### Downloading sacrebleu corpus"

src=$1
trg=$2
output_prefix=$3
dataset=$4

COMPRESSION_CMD="${COMPRESSION_CMD:-pigz}"
ARTIFACT_EXT="${ARTIFACT_EXT:-gz}"

if ! sacrebleu -t "${dataset}" -l "${src}-${trg}" --echo src ; then
    touch "${output_prefix}.source.${ARTIFACT_EXT}"
    touch "${output_prefix}.target.${ARTIFACT_EXT}" 
    echo "Fake touch files created since dataset doesn't exist: ${output_prefix}.source.${ARTIFACT_EXT}"
else #Otherwise create fake dummy empty files
    sacrebleu -t "${dataset}" -l "${src}-${trg}" --echo src | ${COMPRESSION_CMD} -c > "${output_prefix}.source.${ARTIFACT_EXT}"
    sacrebleu -t "${dataset}" -l "${src}-${trg}" --echo ref | ${COMPRESSION_CMD} -c > "${output_prefix}.target.${ARTIFACT_EXT}"
fi

echo "###### Done: Downloading sacrebleu corpus"
