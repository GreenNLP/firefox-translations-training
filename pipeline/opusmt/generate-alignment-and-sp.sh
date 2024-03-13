#!/bin/bash
##
# Generates alignment and runs sentencepiece for corpus used to finetune OPUS-MT models.
#

set -x
set -euo pipefail

echo "###### Generating alignments and shortlist"
test -v MARIAN
test -v BIN
test -v SRC
test -v TRG

corpus_prefix=$1
source_spm_path=$2
target_spm_path=$3
output_dir=$4
threads=$5

cd "$(dirname "${0}")"

mkdir -p "${output_dir}"
dir="${output_dir}/tmp"

#delete tmp dir if it exists, unfinished files will mess up later runs
rm -rf "${dir}"

mkdir -p "${dir}"

corpus_src="${corpus_prefix}.${SRC}.gz"
corpus_trg="${corpus_prefix}.${TRG}.gz"


echo "### Subword segmentation with SentencePiece"
test -s "${dir}/corpus.spm.${SRC}.gz" ||
  pigz -dc "${corpus_src}" |
  parallel --no-notice --pipe -k -j "${threads}" --block 50M "${MARIAN}/spm_encode" --model "${source_spm_path}" |
  pigz >"${output_dir}/corpus.spm.${SRC}.gz"
test -s "${output_dir}/corpus.spm.${TRG}.gz" ||
  pigz -dc "${corpus_trg}" |
  parallel --no-notice --pipe -k -j "${threads}" --block 50M "${MARIAN}/spm_encode" --model "${target_spm_path}" |
  pigz >"${output_dir}/corpus.spm.${TRG}.gz"

echo "### Creating merged corpus"
test -s "${output_dir}/corpus.aln.gz" || test -s "${dir}/corpus" ||
  paste <(pigz -dc "${output_dir}/corpus.spm.${SRC}.gz") <(pigz -dc "${output_dir}/corpus.spm.${TRG}.gz") |
  sed 's/\t/ ||| /' >"${dir}/corpus"

echo "### Training alignments"
test -s "${output_dir}/corpus.aln.gz" || test -s "${dir}/align.s2t.gz" ||
  "${BIN}/fast_align" -vod -i "${dir}/corpus" |
  pigz >"${dir}/align.s2t.gz"
test -s "${output_dir}/corpus.aln.gz" || test -s "${dir}/align.t2s.gz" ||
  "${BIN}/fast_align" -vodr -i "${dir}/corpus" |
  pigz >"${dir}/align.t2s.gz"

echo "### Symmetrizing alignments"
test -s "${output_dir}/corpus.aln.gz" || test -s "${dir}/align.t2s" ||
  pigz -d "${dir}/align.s2t.gz" "${dir}/align.t2s.gz"
test -s "${output_dir}/corpus.aln.gz" ||
  "${BIN}/atools" -i "${dir}/align.s2t" -j "${dir}/align.t2s" -c grow-diag-final-and |
  pigz >"${output_dir}/corpus.aln.gz"

echo "### Deleting tmp dir"
rm -rf "${dir}"

echo "###### Done: Generating alignments and shortlist"
