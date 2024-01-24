#I
#!/bin/bash
# Train a model with opustrainer

set -x
set -euo pipefail

echo "###### Training a model with Opustrainer"

model_type=$1
opustrainer_config=$2
devset=$3
model_dir=$4
vocab=$5
alignment=$6
best_model_metric=$7
extra_params=( "${@:8}" )

COMPRESSION_CMD="${COMPRESSION_CMD:-pigz}"
ARTIFACT_EXT="${ARTIFACT_EXT:-gz}"

#test -v GPUS
#test -v MARIAN
#test -v WORKSPACE

cd "$(dirname "${0}")"
mkdir -p "${model_dir}/tmp"
mkdir -p "${model_dir}/valid_outputs"

all_model_metrics=(chrf ce-mean-words) # not using bleu-detok as it hangs in Marian


echo "### Training ${model_type}"
#./trainer.py -c config.yml --temporary-directory /path/to/temp/dir path-to-your-marian-or-whatever --pass --marian-arguments
# OpusTrainer reads the datasets, shuffles them and feeds to stdin of Marian
#--log-file not working
"opustrainer-train" \
  --config "${opustrainer_config}" \
  "${MARIAN}/marian" \
    --model "${model_dir}/model.npz" \
    -c "configs/model/${model_type}.yml"  "configs/training/${model_type}.train.yml" \
    -T "${model_dir}/tmp" \
    --shuffle batches \
    --vocabs "${vocab}" "${vocab}" \
    -w "${WORKSPACE}" \
    --devices ${GPUS} \
    --sharding local \
    --sync-sgd \
    --valid-metrics "${best_model_metric}" ${all_model_metrics[@]/$best_model_metric} \
    --valid-sets "${devset}" \
    --valid-translation-output "${model_dir}/valid_outputs/validation-output-after-{U}-updates-{E}-epochs.txt" \
    --quiet-translation \
    --overwrite \
    --keep-best \
    --log "${model_dir}/train.log" \
    --valid-log "${model_dir}/valid.log" \
    --tsv \
    "${extra_params[@]}"
    # --guided-alignment "${alignment}"\

cp "${model_dir}/model.npz.best-${best_model_metric}.npz" "${model_dir}/final.model.npz.best-${best_model_metric}.npz"
cp "${model_dir}/model.npz.best-${best_model_metric}.npz.decoder.yml" "${model_dir}/final.model.npz.best-${best_model_metric}.npz.decoder.yml"

echo "### Model training is completed: ${model_dir}"
echo "###### Done: Training a model"
