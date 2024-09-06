#!/bin/bash
#
# Merges translation outputs into a dataset
#

set -x
set -euo pipefail


dir=$1
source_output_path=$2
target_output_path=$3
#model_index=$4

echo "### Collecting translations"
#cat "${dir}"/*${model_index}.out | pigz >"${output_path}"
cat "${dir}"/*.out | pigz >"${output_path}"

echo "### Comparing number of sentences in source and artificial target files"
src_len=$(pigz -dc "${source_output_path}" | wc -l)
trg_len=$(pigz -dc "${target_output_path}" | wc -l)
if [ "${src_len}" != "${trg_len}" ]; then
  echo "### Error: length of ${mono_path} ${src_len} is different from ${output_path} ${trg_len}"
  exit 1
fi
