#!/bin/bash
##
# Train SentencePiece vocabulary model
#

set -x
set -euo pipefail

test -v MARIAN

#control_symbols="<cni>","<aym>","<bzd>","<gn>","<oto>","<nah>","<quy>","<tar>","<shi>","<hch>","<en>" --input="data/processed
corpus_src=$1
corpus_trg=$2
vocab_output=$3
trgs=$4
sample_size=$5
threads=$6
vocab_size="${7:-32000}"

if [ "$threads" = "auto" ]; then
  threads=$(nproc)
fi

COMPRESSION_CMD="${COMPRESSION_CMD:-pigz}"

vocab_dir=$(dirname "${vocab_output}")
mkdir -p "${vocab_dir}"

${COMPRESSION_CMD} -dc "${corpus_src}" >"${vocab_dir}/data.src.txt"
${COMPRESSION_CMD} -dc "${corpus_trg}" >"${vocab_dir}/data.trg.txt"

# if multiple targets, add language token as control token so that the tokenization maintains this as onepiece
if [ "${#trgs}" -gt 3 ]; then
  langtags=">>$(echo "$trgs" | sed 's/ /<<,>>/g')<<" # This creates a list with the target language tags such as >>fin<<,>>est<<
  echo $langtags
  
  "${MARIAN}/spm_train" --bos_id=-1 --eos_id=0 --unk_id=1 --user_defined_symbols="" --control_symbols="${langtags}" \
    --model_prefix="${vocab_dir}/vocab" --vocab_size="${vocab_size}" \
    --input="${vocab_dir}/data.src.txt,${vocab_dir}/data.trg.txt" \
    --input_sentence_size="${sample_size}" --shuffle_input_sentence=true \
    --num_threads "${threads}"
else
  "${MARIAN}/spm_train" --bos_id=-1 --eos_id=0 --unk_id=1 --user_defined_symbols="" \
    --model_prefix="${vocab_dir}/vocab" --vocab_size="${vocab_size}" \
    --input="${vocab_dir}/data.src.txt,${vocab_dir}/data.trg.txt" \
    --input_sentence_size="${sample_size}" --shuffle_input_sentence=true \
    --num_threads "${threads}"
fi

rm "${vocab_dir}/data.src.txt" "${vocab_dir}/data.trg.txt"

mv "${vocab_dir}/vocab.model" "${vocab_output}"
