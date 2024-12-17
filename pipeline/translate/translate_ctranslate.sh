#!/bin/bash
##
# Converts model to ctranslate and translates generating n-best lists as output
#

set -x
set -euo pipefail

# On LUMI, having CUDA_VISIBLE_DEVICES set causes a segfault when using multiple GPUs
unset CUDA_VISIBLE_DEVICES

filein=$1
fileout=$2
modelname=$3
modeldir="${4}-ct2"
src_lang=$5
trg_lang=$6
langinfo=$7
prompt=$8
langtags=$9
config=${10}
batch_size=${11}
logfile=${12}

# convert model
echo "### Converting model with Ctranslate2"

if [ ! -d "${modeldir}" ]; then
    HF_HOME=$modeldir TRANSFORMERS_CACHE=$modeldir ct2-transformers-converter --force --model $modelname --output_dir $modeldir --trust_remote_code
    echo "### Done!"
elif [[ "$modelname" == *"indictrans"* ]]; then
    # Identify model (extract indic-en, en-indic, or indic-indic)
    model=$(echo "$modelname" | grep -oP '(indic-[a-z]+|en-indic|indic-indic)')
    
    echo "### Identified model: $model"
    
    # Download and extract model
    tmpdir="${modeldir}-tmp"
    mkdir -p "$tmpdir"
    
    wget -q "https://indictrans2-public.objectstore.e2enetworks.net/it2_preprint_ckpts/${model}-preprint.zip" -O "${tmpdir}/${model}-preprint.zip"
    
    echo "### Extracting model files..."
    unzip -q "${tmpdir}/${model}-preprint.zip" -d "$tmpdir"
    
    # Move ctranslate converted model to the correct folder
    mv "${tmpdir}/${model}-preprint/ct2_int8_model/"* "$modeldir"
    rm -rf "$tmpdir"
    echo "### Model downloaded and moved to $modeldir!"
else
    echo "### Converted model already exists! Remove to overwrite"
fi

echo "### Translation started"

python pipeline/translate/translate_ctranslate_indictrans.py $filein $fileout.tmp $modelname $modeldir $src_lang $trg_lang $langinfo $prompt "$langtags" $config $batch_size $logfile

echo "### Done!"

echo "### Sorting started"

sort -n -t '|' -k 1,1 $fileout.tmp -o $fileout
rm $fileout.tmp

echo "### Done!"
