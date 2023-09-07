#!/bin/bash
##
# Applies Lang-id for forward translation
#

set -x
set -euo pipefail

echo "###### Adding language tag"

target_lang_token=$1
file=$2
model_dir=$3

#target_lang_token needs to be provided for multilingual models
#first check whether model is multilingual AND preprocessing isdone on source side (never language tags on target side)
if grep -q ">>id<<" "${model_dir}/README.md"; then
    target_lang_token=">>${target_lang_token}<< "
    zcat $file.source.gz | sed "s/^/${target_lang_token}/" | gzip > $file.source.langtagged.gz

    echo "###### Done: Adding language tag"
else
    ln -s $file.source.gz $file.source.langtagged.gz
    echo "The model doesn't have multiple targets, so there is no need to add a language tag"
fi