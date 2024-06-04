#!/bin/bash
##
# Build a fuzzy match index with Systran's fuzzy match tool.
#

set -x
set -euo pipefail

fuzzy_match_cli=$1
src_corpus=$2
trg_corpus=$3
threads=$4
index_file=$5

echo "##### Building a fuzzy match index"

${fuzzy_match_cli} --action index --corpus ${src_corpus} --nthreads ${threads}

# The add-target flag adds the target sentence to the db but there seems to be some bugs associated, so don't use it
#${fuzzy_match_cli} --action index --corpus ${src_corpus},${trg_corpus} --nthreads ${threads} --add-target

# index is saved as src_corpus.fmi, move it to the correct place
mv "${src_corpus}.fmi" "${index_file}"
