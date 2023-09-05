#!/bin/bash
##
# Applies Lang-id for forward translation
#

set -x
set -euo pipefail

echo "###### Adding language tag"

output_dir=$1
type=$2
inputs=( "${@:3}" )

src_lang="source"
trg_lang="target"

tmp="${output_dir}/${type}_tmp"
mkdir -p "${tmp}"
echo $tmp

# Initialize the id counter
id=0

for file in $inputs; do
    # Use basename to get the filename part
    filename=$(basename "$file")

    # Use parameter expansion to extract "fr" from the filename
    target_lang_token="${filename##*-}"
    target_lang_token=">>${target_lang_token}<< "
    zcat $file.source.gz | sed -e "s/^/${target_lang_token}/" | gzip > $tmp/source.$id.gz
    cp $file.target.gz $tmp/target.$id.gz

    # Increment the id counter
    ((id=id+1))
done

echo "###### Done: Adding language tag"

echo "###### Merging "

rm ${output_dir}/${type}*gz

cat `echo $tmp/source.* | tr ' ' '\n' | tr '\n' ' '` >"${output_dir}/${type}.source.${ARTIFACT_EXT}"
cat `echo $tmp/target.* | tr ' ' '\n' | tr '\n' ' '` >"${output_dir}/${type}.target.${ARTIFACT_EXT}"

rm -rf "${tmp}"
 
echo "###### Done: Merging parallel datasets"