#!/bin/bash
##
# Generates alignment for individual language pair for opustrainer training with guided alignment.
#

set -x
set -euo pipefail

echo "###### Generating alignments for individual language pairs"
test -v MARIAN
test -v BIN
test -v SRC
test -v TRG

corpus_prefix=$1
vocab_path=$2
output_dir=$3
o2m_student=$4
threads=$5

cd "$(dirname "${0}")"

mkdir -p "${output_dir}"
dir="${output_dir}/tmp"
mkdir -p "${dir}"

corpus_src="${corpus_prefix}.${SRC}.gz"
corpus_trg="${corpus_prefix}.${TRG}.gz"

test -s "${dir}/cleaned_empty_lines" ||
  echo "### Removing empty target lines"
  paste <(pigz -dc "${corpus_src}") <(pigz -dc "${corpus_trg}") | sed 's/\t/ ||| /' >"${dir}/corpus"
  awk -F ' \\|\\|\\| ' '$1!="" && $2!=""' "${dir}/corpus" > "${dir}/corpus_dedup"

  echo "### Splitting corpus back into source and target files and overwriting source and target files"
  awk -F' \\|\\|\\| ' '{print $1}' "${dir}/corpus_dedup" | pigz -c > "${corpus_src}"
  awk -F' \\|\\|\\| ' '{print $2}' "${dir}/corpus_dedup" | pigz -c > "${corpus_trg}"
  rm "${dir}/corpus"
  rm "${dir}/corpus_dedup"
  touch "${dir}/cleaned_empty_lines"

echo "### Subword segmentation with SentencePiece"
test -s "${dir}/corpus.spm.${SRC}.gz" ||
  pigz -dc "${corpus_src}" | sed "s/^>>.*<< //" |
  parallel --no-notice --pipe -k -j "${threads}" --block 50M "${MARIAN}/spm_encode" --model "${vocab_path}" |
  pigz >"${dir}/corpus.spm.${SRC}.gz"
test -s "${dir}/corpus.spm.${TRG}.gz" ||
  pigz -dc "${corpus_trg}" |
  parallel --no-notice --pipe -k -j "${threads}" --block 50M "${MARIAN}/spm_encode" --model "${vocab_path}" |
  pigz >"${dir}/corpus.spm.${TRG}.gz"

echo "### Creating merged corpus"
test -s "${output_dir}/corpus.aln" || test -s "${dir}/corpus" ||
  paste <(pigz -dc "${dir}/corpus.spm.${SRC}.gz") <(pigz -dc "${dir}/corpus.spm.${TRG}.gz") |
  sed 's/\t/ ||| /' >"${dir}/corpus"

echo "### Removing empty target lines"
awk -F ' \|\|\| ' '$1!="" && $2!=""' "${dir}/corpus" > "${dir}/corpus_clean"
mv "${dir}/corpus_clean" "${dir}/corpus"

echo "### Training alignments"
test -s "${output_dir}/corpus.aln" || test -s "${dir}/align.s2t" || test -s "${dir}/align.t2s" ||
  "eflomal-align" -i "${dir}/corpus" -f "${dir}/align.s2t" -r "${dir}/align.t2s" -m 3

echo "### Symmetrizing alignments"
test -s "${output_dir}/corpus.aln" ||
  "${BIN}/atools" -i "${dir}/align.s2t" -j "${dir}/align.t2s" -c grow-diag-final-and >"${output_dir}/corpus.aln"

echo "### Deleting tmp dir"
rm -rf "${dir}"

# If there are language tags, we need to modify the alignments by adding index 1 to every source token
if [ $o2m_student == "True" ]; then
    echo "###### Correcting alignments taking into account language tags"
    cat "${output_dir}/corpus.aln" | sed -E 's/([0-9]+)-([0-9]+)/echo $((\1+1))"-\2"/ge' |  sed 's/echo //g' > "${output_dir}/corpus.aln.fixed"
    mv "${output_dir}/corpus.aln.fixed" "${output_dir}/corpus.aln"
fi
echo "###### Done: Generating alignments and shortlist"
