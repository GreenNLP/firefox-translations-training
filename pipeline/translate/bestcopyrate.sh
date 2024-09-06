#!/bin/bash
##
# Picks the best translation based on bleu or copy rate with fuzzies
#

set -x
set -euo pipefail

nbest=$1
ref=$2
fuzzy_source=$3
output_source=$4
output_target=$5

# separate the data into ones with fuzzies (suffix .fuzzies) and ones without (suffix .nonfuzzies)
python pipeline/translate/separate_fuzzies.py --nbest "${nbest}" --ref "${ref}" --source "${fuzzy_source}"

# get the best fuzzy translations based on copy rate
python pipeline/translate/bestbleu.py --copyrate -i ${nbest}.fuzzies -r ${ref}.fuzzies -m bleu -o ${output_target}.fuzzies

# get the best non-fuzzy translations based on normal bleu
python pipeline/translate/bestbleu.py -i ${nbest}.nonfuzzies -r ${ref}.nonfuzzies -m bleu -o ${output_target}.nonfuzzies

# combine outputs
cat ${fuzzy_source}.nonfuzzies ${fuzzy_source}.fuzzies > ${output_source}
cat ${output_target}.nonfuzzies ${output_target}.fuzzies > ${output_target}
