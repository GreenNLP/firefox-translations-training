#!/bin/bash
##
# Merges and deduplicates parallel datasets
#

set -x
set -euo pipefail

echo "###### Merging parallel datasets"

test -v SRC
test -v TRG
test -v BIN

output_prefix=$1
max_sents=$2
inputs=( "${@:3}" )

src_lang="source"
trg_lang="target"

COMPRESSION_CMD="${COMPRESSION_CMD:-pigz}"
ARTIFACT_EXT="${ARTIFACT_EXT:-gz}"

tmp="${output_prefix}/merge"
mkdir -p "${tmp}"

echo "### Merging"
if [[ "${inputs[0]}" == *.${ARTIFACT_EXT} ]]; then
  cat `echo ${inputs[@]} | tr ' ' '\n' | grep ${src_lang} | tr '\n' ' '` >"${tmp}/corpus.${src_lang}.dup.${ARTIFACT_EXT}"
  cat `echo ${inputs[@]} | tr ' ' '\n' | grep ${trg_lang} | tr '\n' ' '` >"${tmp}/corpus.${trg_lang}.dup.${ARTIFACT_EXT}"
else
  cat "${inputs[@]/%/.${src_lang}.${ARTIFACT_EXT}}" >"${tmp}/corpus.${src_lang}.dup.${ARTIFACT_EXT}"
  cat "${inputs[@]/%/.${trg_lang}.${ARTIFACT_EXT}}" >"${tmp}/corpus.${trg_lang}.dup.${ARTIFACT_EXT}"
fi

echo "### Deduplication"
paste <(${COMPRESSION_CMD} -dc "${tmp}/corpus.${src_lang}.dup.${ARTIFACT_EXT}") <(${COMPRESSION_CMD} -dc "${tmp}/corpus.${trg_lang}.dup.${ARTIFACT_EXT}") |
${BIN}/dedupe |
${COMPRESSION_CMD} >"${tmp}.${src_lang}${trg_lang}.${ARTIFACT_EXT}"

# if max sents not "inf", get the first n sents (this is mainly used for testing to make translation and training go faster)
if [ "${max_sents}" != "inf" ]; then
    head -${max_sents} <(${COMPRESSION_CMD} -dc "${tmp}.${src_lang}${trg_lang}.gz") | ${COMPRESSION_CMD} > "${tmp}.${src_lang}${trg_lang}.truncated.gz"
    mv "${tmp}.${src_lang}${trg_lang}.truncated.gz" "${tmp}.${src_lang}${trg_lang}.gz"
fi

${COMPRESSION_CMD} -dc "${tmp}.${src_lang}${trg_lang}.${ARTIFACT_EXT}" | cut -f1 | ${COMPRESSION_CMD} > "${output_prefix}.${src_lang}.${ARTIFACT_EXT}"
${COMPRESSION_CMD} -dc "${tmp}.${src_lang}${trg_lang}.${ARTIFACT_EXT}" | cut -f2 | ${COMPRESSION_CMD} > "${output_prefix}.${trg_lang}.${ARTIFACT_EXT}"

rm -rf "${tmp}"

echo "###### Done: Merging parallel datasets"
