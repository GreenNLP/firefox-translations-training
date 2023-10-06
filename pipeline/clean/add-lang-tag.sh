#!/bin/bash
##
# Applies Lang-id for forward translation
#

set -x
set -euo pipefail

echo "###### Adding language tag"

target_lang_token=$1
file=$2
o2m_teacher=$3

# Target_lang_token needs to be provided only for multilingual many2one teacher models
# First check whether model is multilingual AND preprocessing is done on source side (never language tags on target side)
if [ $o2m_teacher == "True" ]; then
    target_lang_token=">>${target_lang_token}<< "
    zcat $file.source.gz | sed "s/^/${target_lang_token}/" | gzip > $file.source.langtagged.gz

    echo "###### Done: Adding language tag"
else
    ln -s $file.source.gz $file.source.langtagged.gz
    echo "The model doesn't have multiple targets, so there is no need to add a language tag, we create a dummy file"
fi