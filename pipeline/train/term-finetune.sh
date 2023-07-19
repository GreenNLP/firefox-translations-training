#!/bin/bash
##
# Finetune model with term data.
#

set -x
set -euo pipefail

echo "###### Finetuning a model with term data"

# On LUMI, having CUDA_VISIBLE_DEVICES set causes a segfault when using multiple GPUs
unset CUDA_VISIBLE_DEVICES

model_type=$1
training_type=$2
src=$3
trg=$4
train_set_prefix=$5
valid_set_prefix=$6
model_dir=$7
vocab=$8
best_model_metric=$9
extra_params=( "${@:10}" )

test -v GPUS
test -v MARIAN
test -v WORKSPACE

cd "$(dirname "${0}")"
mkdir -p "${model_dir}/tmp"

echo "### Training ${model_dir}"

# if doesn't fit in RAM, remove --shuffle-in-ram and add --shuffle batches

"${MARIAN}"/marian \
  --model "${model_dir}/model_unfinished.npz" \
  -c "configs/model/${model_type}.yml" "configs/training/${model_type}.${training_type}.yml" \
  --train-sets "${train_set_prefix}".{"${src}","${trg}"}.gz \
  -T "${model_dir}/tmp" \
  --shuffle-in-ram \
  --vocabs "${vocab}" "${vocab}" \
  -w "${WORKSPACE}" \
  --devices ${GPUS} \
  --sharding local \
  --data-threads 16 \
  --sync-sgd \
  --valid-metrics "${best_model_metric}" ${all_model_metrics[@]/$best_model_metric} \
  --valid-translation-output "${model_dir}/devset.out" \
  --quiet-translation \
  --overwrite \
  --log "${model_dir}/train.log" \
  --valid-log "${model_dir}/valid.log" \
  "${extra_params[@]}"


cp "${model_dir}/model_unfinished.npz" "${model_dir}/model.npz"  
cp "${model_dir}/model_unfinished.npz.decoder.yml" "${model_dir}/model.npz.decoder.npz"  

echo "### Model training is completed: ${model_dir}"
echo "###### Done: Training a model"
