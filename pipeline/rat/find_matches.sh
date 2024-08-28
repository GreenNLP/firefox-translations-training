#!/bin/bash
##
# Find matches from index for a corpus using Systran's fuzzy match tool.
#

set -x
set -euo pipefail

fuzzy_match_cli=$1
source_corpus=$2
threads=$3
index_file=$4
output_file=$5
contrastive_factor=$6

echo "##### Building a fuzzy match index"

zcat ${source_corpus} | ${fuzzy_match_cli} --contrast ${contrastive_factor} --no-perfect --index ${index_file} --fuzzy 0.5 --action match --nthreads ${threads} > $output_file

