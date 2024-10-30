#!/bin/bash
##
# Find matches from index for a corpus using Systran's fuzzy match tool.
#

set -x
set -euo pipefail

fuzzy_match_cli=$1
source_corpus=$2
target_corpus=$3
eflomal_priors=$4
threads=$5
index_file=$6
output_file=$7
contrastive_factor=$8
src_lang=$9
trg_lang=${10}
use_ngrams=${11:-false}

if [[ $output_file == *"targetsim"* ]]; then
  targetsim="--targetsim"
else
  targetsim=""
fi

echo "##### Finding matches"

if [ "$use_ngrams" = "true" ] ; then
  full_match_file="$(dirname $output_file)/$(basename $output_file .gz).full.gz"
  zcat ${source_corpus} | ${fuzzy_match_cli} --contrast ${contrastive_factor} --no-perfect --index ${index_file} --fuzzy 0.2 --mr 0.2 --ml 5 --action match --nthreads ${threads} | gzip > $full_match_file &&
  python pipeline/rat/extract_ngrams.py --match_file $full_match_file --source_file $source_corpus --target_file $target_corpus --priors_file $eflomal_priors --src_lang $src_lang --trg_lang $trg_lang $targetsim --output_file $output_file
else
  zcat ${source_corpus} | ${fuzzy_match_cli} --contrast ${contrastive_factor} --no-perfect --index ${index_file} --fuzzy 0.5 --action match --nthreads ${threads} | gzip > $output_file
fi