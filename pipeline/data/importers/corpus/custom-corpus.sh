#!/bin/bash
##
# Use custom dataset that is already downloaded to a local disk
# Local path prefix without `.<lang_code>.gz` should be specified as a "dataset" parameter
#

set -x
set -euo pipefail

echo "###### Copying custom corpus"

src=$1
trg=$2
output_prefix=$3
dataset=$4

# Check if file exists, otherwise create dummy files
if test -e "${dataset}.${src}.gz"; then
    echo "File exists."
    cp "${dataset}.${src}.gz" "${output_prefix}.source.gz"
    cp "${dataset}.${trg}.gz" "${output_prefix}.target.gz"

else
    echo "File does not exist. Creating dummy files."
    touch "${output_prefix}.source.gz"
    touch "${output_prefix}.target.gz"
    echo "Fake touch files created since dataset doesn't exist: ${output_prefix}.${trg}.gz"
fi

echo "###### Done: Copying custom corpus"