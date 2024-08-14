#!/bin/bash
##
# Train a model.
#

set -x
set -euo pipefail

echo "###### Training a model"

# On LUMI, having CUDA_VISIBLE_DEVICES set causes a segfault when using multiple GPUs
unset CUDA_VISIBLE_DEVICES

model_type=$1
training_type=$2
src=$3
trg=$4
train_set_src=$5
train_set_trg=$6
valid_set_src=$7
valid_set_trg=$8
model=$9
model_dir=$(dirname ${model})
vocab=${10}
best_model_metric=${11}
extra_params=( "${@:12}" )

cd "$(dirname "${0}")"
mkdir -p "${model_dir}/tmp"

all_model_metrics=(chrf ce-mean-words bleu-detok)

echo "### Training ${model_dir}"

# if doesn't fit in RAM, remove --shuffle-in-ram and add --shuffle batches

"${MARIAN}"/marian \
  --model "${model_dir}/model.npz" \
  -c "configs/model/${model_type}.yml" "configs/training/${model_type}.${training_type}.yml" \
  --train-sets "${train_set_src}" "${train_set_trg}" \
  -T "${model_dir}/tmp" \
  --shuffle-in-ram \
  --vocabs "${vocab}" "${vocab}" \
  -w "${WORKSPACE}" \
  --devices ${GPUS} \
  --sharding local \
  --data-threads 16 \
  --sync-sgd \
  --valid-metrics "${best_model_metric}" ${all_model_metrics[@]/$best_model_metric} \
  --valid-sets "${valid_set_src}" "${valid_set_trg}" \
  --valid-translation-output "${model_dir}/devset.out" \
  --quiet-translation \
  --overwrite \
  --keep-best \
  --log "${model_dir}/train.log" \
  --valid-log "${model_dir}/valid.log" \
  "${extra_params[@]}"

cp "${model_dir}/model.npz.best-${best_model_metric}.npz" "${model_dir}/final.model.npz.best-${best_model_metric}.npz"
cp "${model_dir}/model.npz.best-${best_model_metric}.npz.decoder.yml" "${model_dir}/final.model.npz.best-${best_model_metric}.npz.decoder.yml"

echo "### Model training is completed: ${model_dir}"
echo "###### Done: Training a model"
