#!/bin/bash
##
# Finetune model with term data.
#

set -x
set -euo pipefail

echo "###### Finetuning a model with term data"

# On LUMI, having CUDA_VISIBLE_DEVICES set causes a segfault when using multiple GPUs
unset CUDA_VISIBLE_DEVICES

src=$1
trg=$2
train_set_prefix=$3
valid_set_prefix=$4
model_dir=$5
base_model=$6
base_model_dir=$(dirname ${base_model})
best_model_metric=$7
extra_params=( "${@:8}" )
vocab="${model_dir}/vocab.yml"

test -v GPUS
test -v MARIAN
test -v WORKSPACE

cd "$(dirname "${0}")"


mkdir -p "${model_dir}/tmp"
cp ${base_model_dir}/source.spm ${model_dir}
cp ${base_model_dir}/target.spm ${model_dir}
cp ${base_model_dir}/vocab.yml ${model_dir}

# Modify vocab to contain three augmentation symbols
python ./add_term_symbols.py \
  --source_spm_model ${model_dir}/source.spm \
  --target_spm_model ${model_dir}/target.spm \
  --yaml_vocab ${vocab}

echo "### Training ${model_dir}"

# if doesn't fit in RAM, remove --shuffle-in-ram and add --shuffle batches

"${MARIAN}"/marian \
  --task transformer-big \
  --model "${model_dir}/model_unfinished.npz" \
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
  --pretrained-model "${base_model}" \
  "${extra_params[@]}"


cp "${model_dir}/model_unfinished.npz" "${model_dir}/model.npz"  
cp "${model_dir}/model_unfinished.npz.decoder.yml" "${model_dir}/model.npz.decoder.npz"  

echo "### Model training is completed: ${model_dir}"
echo "###### Done: Training a model"
