#!/bin/bash
##
# Downloads a pretrained opus mt (or tatoeba-challenge) model
#

set -x
set -euo pipefail

echo "###### Downloading pretrained opus model"

download_url=$1

model_dir=$2
best_model=$3
source_lang=$4
target_lang=$5

mkdir -p $model_dir

#if download url is best, find the best model from list
if [[ $download_url = "best" ]]
then
    model_list="${model_dir}/top-bleu-scores.txt"
    wget -O ${model_list} "https://raw.githubusercontent.com/Helsinki-NLP/OPUS-MT-leaderboard/master/scores/${source_lang}-${target_lang}/top-bleu-scores.txt"

    #https://raw.githubusercontent.com/Helsinki-NLP/Tatoeba-Challenge/master/models/released-model-results.txt"
    download_url=$(grep flores101-devtest ${model_list} |  cut -f 3)
    echo "###### Using best ${source_lang}-${target_lang} model ${download_url}"
    model_target=$(echo "$download_url" | cut -d'/' -f5 | cut -d '-' -f2) #check if the target language equals the dowload url > ture otherwise false
    if [ $model_target == $target_lang ]; then   
        o2m="False"
    else
        o2m="True"
    fi
    echo ${o2m} > ${model_dir}/one2many.txt # Read the content of the file
    echo "Model is multilingual to the target side: $o2m"
fi

model_zip=${download_url##*/}
archive_path="${model_dir}/${model_zip}"

wget -O "${archive_path}" "${download_url}"

cd ${model_dir}
unzip -j -o "${model_zip}"
rm ${model_zip}

model_file=$(ls *.npz)
vocab_file=$(ls *vocab.yml)
#Create a soft link for the model with the name that the workflow expects 
ln -s $model_file ${best_model}
#Also create a standard name link for the vocab
ln -s $vocab_file "vocab.yml"

echo "###### Done: Downloading and extracting opus mt model"
