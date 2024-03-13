#!/bin/bash
##
# Generates alignment for evalsets.
#

set -x
set -euo pipefail

echo "###### Generating alignments"
test -v MARIAN
test -v BIN
test -v SRC
test -v TRG

evalset_src=$1
evalset_trg=$2
train_src=$3
train_trg=$4
src_vocab_path=$5
trg_vocab_path=$6
output_dir=$7
threads=$8

evalsets_length=$(zcat ${evalset_src} | wc -l)

cd "$(dirname "${0}")"

mkdir -p "${output_dir}"
dir="${output_dir}/tmp"

#Delete existing tmp dir, unfinished files will mess up later runs
rm -rf "${dir}"

mkdir -p "${dir}"

# bulk up the evalset with part of the train set, to enable alignment
aln_corpus_src=${dir}/aln_corpus.src
aln_corpus_trg=${dir}/aln_corpus.trg

echo "#### Creating alignment corpus"
zcat ${evalset_trg}  > "${aln_corpus_trg}"
head -n 10000000 <(zcat "${train_trg}") >> "${aln_corpus_trg}"
zcat ${evalset_src} > "${aln_corpus_src}"
head -n 10000000 <(zcat "${train_src}") >> "${aln_corpus_src}"


echo "### Subword segmentation with SentencePiece"
test -s "${dir}/corpus.spm.${SRC}.gz" ||
  cat "${aln_corpus_src}" |
  parallel --no-notice --pipe -k -j "${threads}" --block 50M "${MARIAN}/spm_encode" --model "${src_vocab_path}" |
  pigz >"${dir}/corpus.spm.${SRC}.gz"
test -s "${dir}/corpus.spm.${TRG}.gz" ||
  cat "${aln_corpus_trg}" |
  parallel --no-notice --pipe -k -j "${threads}" --block 50M "${MARIAN}/spm_encode" --model "${trg_vocab_path}" |
  pigz >"${dir}/corpus.spm.${TRG}.gz"

echo "### Creating merged corpus"
test -s "${output_dir}/evalsets.aln.gz" || test -s "${dir}/corpus" ||
  paste <(pigz -dc "${dir}/corpus.spm.${SRC}.gz") <(pigz -dc "${dir}/corpus.spm.${TRG}.gz") |
  sed 's/\t/ ||| /' >"${dir}/corpus"

echo "### Training alignments"
test -s "${output_dir}/evalsets.aln.gz" || test -s "${dir}/align.s2t.gz" ||
  "${BIN}/fast_align" -vod -i "${dir}/corpus" |
  pigz >"${dir}/align.s2t.gz"
test -s "${output_dir}/evalsets.aln.gz" || test -s "${dir}/align.t2s.gz" ||
  "${BIN}/fast_align" -vodr -i "${dir}/corpus" | 
  pigz >"${dir}/align.t2s.gz"

echo "### Symmetrizing alignments"
test -s "${output_dir}/evalsets.aln.gz" || test -s "${dir}/align.t2s" ||
  pigz -d "${dir}/align.s2t.gz" "${dir}/align.t2s.gz"
test -s "${dir}/full.aln.gz" ||
  "${BIN}/atools" -i "${dir}/align.s2t" -j "${dir}/align.t2s" -c grow-diag-final-and |
  pigz >"${dir}/full.aln.gz"

head -n ${evalsets_length} <(zcat "${dir}/full.aln.gz") | gzip > "${output_dir}/evalsets.aln.gz"
head -n ${evalsets_length} <(zcat "${dir}/corpus.spm.${SRC}.gz") | gzip > "${output_dir}/evalsets.spm.src.gz"
head -n ${evalsets_length} <(zcat "${dir}/corpus.spm.${TRG}.gz") | gzip > "${output_dir}/evalsets.spm.trg.gz"

echo "### Deleting tmp dir"
rm -rf "${dir}"

echo "###### Done: Generating alignments and segmented corpus"
