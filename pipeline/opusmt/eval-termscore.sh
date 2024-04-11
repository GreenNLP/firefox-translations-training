#!/bin/bash
##
# Score model against wmt23 termtask dev and test.
#

set -x
set -euo pipefail

# On LUMI, having CUDA_VISIBLE_DEVICES set causes a segfault when using multiple GPUs
unset CUDA_VISIBLE_DEVICES


eval_src=$1
src=$2
trg=$3
decoder_config=$4
models=$5
vocab=$6
res_prefix=$7
sgm_source=$8
sgm_ref=$9
args=( "${@:10}" )


mkdir -p "$(basename "${res_prefix}")"

# generate termless translations the same way for both base and term models
cat "${eval_src}" |  perl -pe 's/augmentsymbol0 (.*?) augmentsymbol1 .*? augmentsymbol2/\1/g' |
  tee "${res_prefix}.eval.noterms.${src}" |
  "${MARIAN}"/marian-decoder \
  -c "${decoder_config}" \
  --quiet \
  --quiet-translation \
  --log "${res_prefix}.log" \
  --models ${models} \
  --vocabs "${vocab}" "${vocab}" \
  "${args[@]}" > "${res_prefix}.eval.noterms.${trg}"

# Check whether this is a term model, preprocess source accordingly
model_base_dir=$(basename $(dirname ${models}))
term_model_regex="^.*term-([a-z-]+)-[0-9]+-[0-9]+"
if [[ $model_base_dir =~ $term_model_regex ]]; then
  cat "${eval_src}" |
  tee "${res_prefix}.eval.${src}" |
    "${MARIAN}"/marian-decoder \
      -c "${decoder_config}" \
      --quiet \
      --quiet-translation \
      --log "${res_prefix}.log" \
      --models ${models} \
      --vocabs "${vocab}" "${vocab}" \
      "${args[@]}" > "${res_prefix}.eval.${trg}"
else
  cat "${eval_src}" |  perl -pe 's/augmentsymbol0 (.*?) augmentsymbol1 (.*?) augmentsymbol2/\2/g' |
  tee "${res_prefix}.eval.${src}" |
    "${MARIAN}"/marian-decoder \
      -c "${decoder_config}" \
      --quiet \
      --quiet-translation \
      --log "${res_prefix}.log" \
      --models ${models} \
      --vocabs "${vocab}" "${vocab}" \
      "${args[@]}" > "${res_prefix}.eval.${trg}"
fi

# Evaluate term output
python 3rd_party/soft-term-constraints/src/sgm_generator.py --hypothesis_only --input_trg_path "${res_prefix}.eval.${trg}" --source_lang_code ${src} --target_lang_code ${trg} --set_id evalset --output_trg_path "${res_prefix}.eval.sgm.${trg}"

python 3rd_party/terminology_evaluation/evaluate_term_wmt.py --language ${trg} --hypothesis "${res_prefix}.eval.sgm.${trg}" --source "${sgm_source}" --target_reference "${sgm_ref}" --log "${res_prefix}.score" --EXACT_MATCH True --WINDOW_OVERLAP True --MOD_TER True --TER True --COMET True --match_counts_path "${res_prefix}.match_counts" --comet_model_path ../comet_models/models--Unbabel--wmt22-comet-da/snapshots/371e9839ca4e213dde891b066cf3080f75ec7e72/checkpoints/model.ckpt 

# Evaluate termless output
python 3rd_party/soft-term-constraints/src/sgm_generator.py --hypothesis_only --input_trg_path "${res_prefix}.eval.noterms.${trg}" --source_lang_code ${src} --target_lang_code ${trg} --set_id evalset --output_trg_path "${res_prefix}.eval.noterms.sgm.${trg}"

python 3rd_party/terminology_evaluation/evaluate_term_wmt.py --language ${trg} --hypothesis "${res_prefix}.eval.noterms.sgm.${trg}" --source "${sgm_source}" --target_reference "${sgm_ref}" --log "${res_prefix}.noterms.score" --EXACT_MATCH True --WINDOW_OVERLAP True --MOD_TER True --TER True --COMET True --match_counts_path "${res_prefix}.noterms.match_counts" --comet_model_path ../comet_models/models--Unbabel--wmt22-comet-da/snapshots/371e9839ca4e213dde891b066cf3080f75ec7e72/checkpoints/model.ckpt 

