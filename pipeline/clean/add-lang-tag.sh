#!/bin/bash
##
# Applies Lang-id for forward translation
#

set -x
set -euo pipefail

echo "###### Adding language tag"

target_lang_token=$1
file=$2
o2m=$3
suffix=$4
model_dir=$5
lang="${suffix//student./}"           

if [ $o2m == "best" ]; then   
    o2m=$(cat ${model_dir}/one2many.txt)  # Read the content of the file
    echo "Model is multilingual to the target side: $o2m"
fi

# Target_lang_token needs to be provided only for multilingual many2one teacher models
# First check whether model is multilingual AND preprocessing is done on source side (never language tags on target side)
if [ $o2m == "True" ]; then
    target_lang_token=">>${target_lang_token}<< "
    # Check if there is already a language tag token
    if zgrep -q "${target_lang_token}" $file.$suffix.gz; then
        ln -s $file.$lang.gz $file.$suffix.langtagged.gz
        echo "The file already contains language tags, we create a dummy file"
    else
        zcat $file.$lang.gz | sed "s/^/${target_lang_token}/" | pigz > $file.$suffix.langtagged.gz
        echo "###### Done: Adding language tag"
    fi
else
    ln -s $file.$lang.gz $file.$suffix.langtagged.gz
    echo "The model doesn't have multiple targets, so there is no need to add a language tag, we create a dummy file"
fi