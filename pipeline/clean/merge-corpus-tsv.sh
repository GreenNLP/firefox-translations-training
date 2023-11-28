#!/bin/bash
##
# Merges and deduplicates parallel datasets
#

set -x
set -euo pipefail

echo "###### Merging parallel datasets into tsv file"

test -v SRC
test -v TRG
test -v BIN

output_prefix=$1
inputs=( "${@:2}" )

src_lang="source.langtagged" # BE MINDFUL THIS SHOULD BE CHANGED FOR BACKWARD
trg_lang="target"

COMPRESSION_CMD="${COMPRESSION_CMD:-pigz}"
ARTIFACT_EXT="${ARTIFACT_EXT:-gz}"

tmp="${output_prefix}/merge_tsv"
mkdir -p "${tmp}"

echo "### Merging"
${COMPRESSION_CMD} -dc "${inputs[@]/%/.${src_lang}.${ARTIFACT_EXT}}" >"${tmp}/corpus.${src_lang}.${ARTIFACT_EXT}"
${COMPRESSION_CMD} -dc "${inputs[@]/%/.${trg_lang}.${ARTIFACT_EXT}}" >"${tmp}/corpus.${trg_lang}.${ARTIFACT_EXT}"

paste "${tmp}/corpus.${src_lang}.${ARTIFACT_EXT}" "${tmp}/corpus.${trg_lang}.${ARTIFACT_EXT}" > "${output_prefix}.tsv"

rm -rf "${tmp}"

echo "###### Done: Merging parallel datasets into tsv file"