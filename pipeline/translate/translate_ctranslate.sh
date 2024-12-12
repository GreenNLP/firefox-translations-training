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
    HF_HOME=$modeldir TRANSFORMERS_CACHE=$modeldir ct2-transformers-converter --force --model $modelname --output_dir $modeldir
    echo "### Done!"
else
    echo "### Converted model already exists! Remove to overwrite"
fi

echo "### Translation started"

python pipeline/translate/translate_ctranslate.py $filein $fileout.tmp $modelname $modeldir $src_lang $trg_lang $langinfo $prompt "$langtags" $config $batch_size $logfile

echo "### Done!"

echo "### Sorting started"

sort -n -t '|' -k 1,1 $fileout.tmp -o $fileout
rm $fileout.tmp

echo "### Done!"
