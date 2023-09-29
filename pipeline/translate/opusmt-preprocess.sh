#!/bin/bash
##
# Applies OPUS-MT preprocessing to corpus
#

set -x
set -euo pipefail


source_file=$1
opusmt_model=$2
spm_name=$3
spm_encoder=$4
o2m_teacher=$5
src=$6
m2o_teacher=$7
export PATH=$PATH:$(dirname ${spm_encoder})
model_dir=$(dirname $opusmt_model)

# When splits are preprocessed, different models need different preprocessing,
# so model index is given. Check for unset parameter.
if [ $# -ge 8 ]; then
    model_index_suffix=".$8"
else
    model_index_suffix=""
fi


if [ "${source_file##*.}" == "gz" ]; then #This applies when scoring
    echo "source file is gzipped"
    if [ $o2m_teacher == "True" ]; then
        zcat $1 |  sed "s/^>>.*<< //" | pipeline/translate/preprocess.sh "${model_dir}/${spm_name}" | gzip > ${source_file%%.gz}${model_index_suffix}.opusmt.gz
    elif [ "${m2o_teacher}" == "True" ]; then # In case the are multiple source languages, we need to add langtag for scoring
        zcat $1 | sed "s/^/>>${src}<< //" | pipeline/translate/preprocess.sh "${model_dir}/${spm_name}" | gzip > ${source_file%%.gz}${model_index_suffix}.opusmt.gz
    else
        zcat $1 | pipeline/translate/preprocess.sh "${model_dir}/${spm_name}" | gzip > ${source_file%%.gz}${model_index_suffix}.opusmt.gz
    fi
else
    echo "source file is not gzipped"
    out_file=$1${model_index_suffix}.opusmt
    if [ $o2m_teacher == "True" ]; then
        while IFS= read -r line; do
                # Get the language tag
                target_lang_token="$(echo "$line" | egrep -o "^>>.*<< ")"
                # Remove it from the sentence
                line="$(echo "$line" | sed "s/$target_lang_token//")"
                # Encode and paste
                echo $line | pipeline/translate/preprocess.sh "${model_dir}/${spm_name}" | sed -e "s/^/${target_lang_token}/" >> $out_file
        done < $source_file
    else
        pipeline/translate/preprocess.sh "${model_dir}/${spm_name}" < $1 > $1${model_index_suffix}.opusmt
    fi
fi