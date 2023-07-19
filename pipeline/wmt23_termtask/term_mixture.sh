#!/bin/bash
##
# Translate with a mixture of term-augmented models using nbest lists.
#

set -x
set -euo pipefail

# On LUMI, having CUDA_VISIBLE_DEVICES set causes a segfault when using multiple GPUs
unset CUDA_VISIBLE_DEVICES

echo "##### Translating with a mixture of term-augmented models using nbest lists."

unannotated_src=$1
dict=$2
src=$3
trg=$4
decoder_config=$5
vocab=$6
res_prefix=$7
beam_size=$8
models=( "${@:9}" )
echo ${models[@]}
output_files=""
mkdir -p "$(dirname "${res_prefix}")"

# Check whether this is a term model 
for model in "${models[@]}"
do
  src_file=${unannotated_src}
  annotation_scheme="unannotated"
  model_base_dir=$(basename $(dirname ${model}))
  term_model_regex="^.*term-([a-z-]+)-[0-9]+-[0-9]+(-omit)?"
  if [[ $model_base_dir =~ $term_model_regex ]]; then
    echo "###### Annotating terms to input file"
    annotation_scheme="${BASH_REMATCH[1]}"
    # Add term augmentation annotations to test set
    annotated_src_file=${res_prefix}.${annotation_scheme}.src
    python 3rd_party/soft-term-constraints/src/annotate.py --annotation_method "${annotation_scheme}" --source_file ${src_file} --source_lang ${src} --target_lang ${trg} --terms_per_sentence ${dict} --source_output_path ${annotated_src_file} --term_start_tag augmentsymbol0 --term_end_tag augmentsymbol1 --trans_end_tag augmentsymbol2
    src_file=${annotated_src_file}
  fi
  output_file="${res_prefix}.${model_base_dir}.${trg}"
  output_files="${output_files} ${output_file}"
  "${MARIAN}"/marian-decoder \
      --input "${src_file}" \
      -c "${decoder_config}" \
      --quiet \
      --output "${output_file}".nbest \
      --devices $GPUS \
      --quiet-translation \
      --log "${res_prefix}.log" \
      --models ${model} \
      --vocabs "${vocab}" "${vocab}" \
      --n-best \
      --workspace 10000 \
      --beam-size ${beam_size} \
      "${args[@]}"
    sed -r "s/^[^|]+\|\|\|([^|]*)\|\|\|.*/\1/g" ${output_file}.nbest | sed -r "s/^ *//g" | sed -r "s/ *$//g" > "${output_file}"
done

# Pick the best translations

python pipeline/wmt23_termtask/best_term_translation.py --system_outputs ${output_files} --output_lang ${trg} --terms ${dict} --nbest_size ${beam_size} --mixture_output "${res_prefix}.mixture.${trg}" > ${res_prefix}.debug

python pipeline/wmt23_termtask/wmt23_score.py --system_output "${res_prefix}.mixture.${trg}" --output_lang ${trg} --terms ${dict} > ${res_prefix}.score

# Generate the wmt23 result format
paste --delimiters \| "${unannotated_src}" /dev/null /dev/null "${res_prefix}.mixture.${trg}" | sed "s/|||/ ||| /g" > ${res_prefix}.wmt23

echo "##### Done: Translating with a mixture of term-augmented models using nbest lists."
