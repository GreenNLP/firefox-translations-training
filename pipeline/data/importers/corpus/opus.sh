#!/bin/bash
##
# Downloads corpus using opus
#

set -x
#set -euo pipefail

echo "###### Downloading opus corpus"

src=$1
trg=$2
output_prefix=$3
dataset=$4

COMPRESSION_CMD="${COMPRESSION_CMD:-pigz}"
ARTIFACT_EXT="${ARTIFACT_EXT:-gz}"

name=${dataset%%/*}
name_and_version="${dataset//[^A-Za-z0-9_- ]/_}"

tmp="$(dirname "${output_prefix}")/opus/${name_and_version}"
mkdir -p "${tmp}"

archive_path="${tmp}/${name}.txt.zip"

wget -q "https://object.pouta.csc.fi/OPUS-${dataset}/moses/${src}-${trg}.txt.zip"
wget_output_1=$?

wget -q "https://object.pouta.csc.fi/OPUS-${dataset}/moses/${trg}-${src}.txt.zip"
wget_output_2=$?

# Attempt to download the file using the first URL
if [ $wget_output_1 -eq 0 ] || [ $wget_output_2 -eq 0 ]; then
  wget -O "${archive_path}" "https://object.pouta.csc.fi/OPUS-${dataset}/moses/${src}-${trg}.txt.zip" ||
    wget -O "${archive_path}" "https://object.pouta.csc.fi/OPUS-${dataset}/moses/${trg}-${src}.txt.zip"

  unzip -o "${archive_path}" -d "${tmp}"

  ${COMPRESSION_CMD} -c "${tmp}/${name}.${src}-${trg}.${src}" > "${output_prefix}.source.${ARTIFACT_EXT}" ||
      ${COMPRESSION_CMD} -c "${tmp}/${name}.${trg}-${src}.${src}" > "${output_prefix}.source.${ARTIFACT_EXT}"
  ${COMPRESSION_CMD} -c "${tmp}/${name}.${src}-${trg}.${trg}" > "${output_prefix}.target.${ARTIFACT_EXT}" ||
      ${COMPRESSION_CMD} -c "${tmp}/${name}.${trg}-${src}.${trg}" > "${output_prefix}.target.${ARTIFACT_EXT}"

else #Otherwise create fake dummy empty files
    touch "${output_prefix}.source.${ARTIFACT_EXT}"
    touch "${output_prefix}.target.${ARTIFACT_EXT}" 
    echo "Fake touch files created since dataset doesn't exist: ${output_prefix}.source.${ARTIFACT_EXT}"
fi

rm -rf "${tmp}"


echo "###### Done: Downloading opus corpus"
