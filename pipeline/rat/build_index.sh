#!/bin/bash
##
# Build a fuzzy match index with Systran's fuzzy match tool.
#

set -x
set -euo pipefail

fuzzy_match_cli=$1
src_corpus=$2
trg_corpus=$3
index_file=$4

echo "##### Building a fuzzy match index"

# index building runs on single thread, --nthreads is only for matching
# ${fuzzy_match_cli} --action index --corpus ${src_corpus}

# Store strings in index. I've also modified fuzzy-match to store source in the index
${fuzzy_match_cli} --action index --corpus ${src_corpus},${trg_corpus} --add-target

# index is saved as src_corpus.fmi, move it to the correct place
mv "${src_corpus}.fmi" "${index_file}"
