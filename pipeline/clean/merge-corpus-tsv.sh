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

prefix=$1
src_lang=$2
alignments=$3

#src_lang="source.langtagged" # BE MINDFUL THIS SHOULD BE CHANGED FOR BACKWARD
trg_lang="target"

COMPRESSION_CMD="${COMPRESSION_CMD:-pigz}"
ARTIFACT_EXT="${ARTIFACT_EXT:-gz}"

tmp="${prefix}/merge_tsv"
mkdir -p "${tmp}"

echo "### Merging"
${COMPRESSION_CMD} -dc "${prefix}.${src_lang}.${ARTIFACT_EXT}" >"${tmp}/corpus.${src_lang}.${ARTIFACT_EXT}"
${COMPRESSION_CMD} -dc "${prefix}.${trg_lang}.${ARTIFACT_EXT}" >"${tmp}/corpus.${trg_lang}.${ARTIFACT_EXT}"

if [ -n "${alignments}" ]; then
    paste "${tmp}/corpus.${src_lang}.${ARTIFACT_EXT}" "${tmp}/corpus.${trg_lang}.${ARTIFACT_EXT}" "${alignments}" > "${prefix}.tsv"
else
    paste "${tmp}/corpus.${src_lang}.${ARTIFACT_EXT}" "${tmp}/corpus.${trg_lang}.${ARTIFACT_EXT}" > "${prefix}.tsv"
fi

rm -rf "${tmp}"

echo "###### Done: Merging parallel datasets into tsv file"