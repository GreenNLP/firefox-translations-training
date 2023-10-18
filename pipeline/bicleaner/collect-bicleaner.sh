#!/bin/bash
#
# Merges translation outputs into a dataset
#

set -x
set -euo pipefail

parts_dir=$1
output=$2

echo "### Collecting bicleaner output"
zcat "${parts_dir}"/bicleaned.file.*.scored.gz > "${output}"
