#!/bin/bash
##
# Cleans corpus using bicleaner-ai or bicleaner
#

set -x
set -euo pipefail

scores=$1
output_prefix=$2
bicleaner_threshold=$3
SRC=$4
TRG=$5

COMPRESSION_CMD="${COMPRESSION_CMD:-pigz}"
ARTIFACT_EXT="${ARTIFACT_EXT:-gz}"

output_dir=$(dirname "${output_prefix}")

if [ "${bicleaner_threshold}" == "0" ]; then
  echo "Threshold is 0, skipping filtering"
  echo "### Writing output corpus"
  ${COMPRESSION_CMD} -dc "${output_prefix}.scored.${ARTIFACT_EXT}" |
    tee >(cut -f1 | ${COMPRESSION_CMD} >"${output_prefix}.${SRC}.${ARTIFACT_EXT}") |
    cut -f2 | ${COMPRESSION_CMD} >"${output_prefix}.${TRG}.${ARTIFACT_EXT}"
else
  echo "### Filtering"
  ${COMPRESSION_CMD} -dc "${output_prefix}.scored.${ARTIFACT_EXT}" |
    awk -v threshold=${bicleaner_threshold} -F"\t" '{if ($3>threshold) {print $0}}' |
    ${COMPRESSION_CMD} >"${output_prefix}.best.${ARTIFACT_EXT}"

  echo "Lines before filtering: $(${COMPRESSION_CMD} -dc "${output_prefix}.scored.${ARTIFACT_EXT}" | wc -l)"
  echo "Lines after filtering: $(${COMPRESSION_CMD} -dc "${output_prefix}.best.${ARTIFACT_EXT}" | wc -l)"

  echo "### Writing output corpus"
  ${COMPRESSION_CMD} -dc "${output_prefix}.best.${ARTIFACT_EXT}" |
    tee >(cut -f1 | ${COMPRESSION_CMD} >"${output_prefix}.${SRC}.${ARTIFACT_EXT}") |
    cut -f2 | ${COMPRESSION_CMD} >"${output_prefix}.${TRG}.${ARTIFACT_EXT}"

  # do not delete intermediate files to inspect them and tune the threshold
fi

echo "###### Done: Bicleaner filtering"
