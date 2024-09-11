#!/bin/bash
##
# Downloads a dataset using mtdata
#

set -x
set -euo pipefail

echo "###### Downloading mtdata corpus"

src=$1
trg=$2
output_prefix=$3
dataset=$4

COMPRESSION_CMD="${COMPRESSION_CMD:-pigz}"
ARTIFACT_EXT="${ARTIFACT_EXT:-gz}"

tmp="$(dirname "${output_prefix}")/mtdata/${dataset}"
mkdir -p "${tmp}"

src_iso=$(python3 -c "from mtdata.iso import iso3_code; print(iso3_code('${src}', fail_error=True))")
trg_iso=$(python3 -c "from mtdata.iso import iso3_code; print(iso3_code('${trg}', fail_error=True))")

if ! mtdata get -l "${src}-${trg}" -tr "${dataset}" -o "${tmp}"; then
    touch "${output_prefix}.source.${ARTIFACT_EXT}"
    touch "${output_prefix}.target.${ARTIFACT_EXT}" 
    echo "Fake touch files created since dataset doesn't exist: ${output_prefix}.source.${ARTIFACT_EXT}"
else #Otherwise create fake dummy empty files
    mtdata get -l "${src}-${trg}" -tr "${dataset}" -o "${tmp}"

    find "${tmp}"

    cat "${tmp}/train-parts/${dataset}.${src_iso}" | ${COMPRESSION_CMD} -c > "${output_prefix}.source.${ARTIFACT_EXT}"
    cat "${tmp}/train-parts/${dataset}.${trg_iso}" | ${COMPRESSION_CMD} -c > "${output_prefix}.target.${ARTIFACT_EXT}"
fi

rm -rf "${tmp}"

echo "###### Done: Downloading mtdata corpus"
