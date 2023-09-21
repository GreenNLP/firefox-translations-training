#!/bin/bash
##
# Downloads bicleaner-ai or bicleaner language pack
#

set -x
# don't use pipefail here because of wget check
set -eu

test -v SRC
test -v TRG

download_path=$1
type=$2

mkdir -p download_path

invalid_url() {
  wget -S --spider -o - $1 | grep -q '404 Not Found'
}

# compatibility fix for earlier bicleaner-ai versions, they don't allow download path
export HF_HOME=${download_path}

if [ "${type}" == 'bicleaner-ai' ]; then
    #bicleaner-ai v2.0 full models are only available through Hugging Face.    
    bicleaner-ai-download ${SRC} ${TRG} full ${download_path} --debug
    url="bicleaner-ai-download"
    #compatibility fix for earlier bicleaner-ai versions
    if [ ! -f "${download_path}/config.json" ]; then
      config_path=$(find ${download_path} -name "config.json")
      model_dir=$(dirname ${config_path})
      # the snapshot files are soft links to blobs in the HF cache
      cp --dereference "${model_dir}/"* ${download_path}
      rm -r "${download_path}/hub"
      # the bicleaner script checks for folder with model lang dir, create it
      model_src=$(grep "source_lang:" "${download_path}"/metadata.yaml | cut -f2 -d ':' | tr -d ' ') 
      model_trg=$(grep "target_lang:" "${download_path}"/metadata.yaml | cut -f2 -d ':' | tr -d ' ')
      mkdir "${download_path}/${model_src}-${model_trg}"
    fi
elif [ "${type}" == 'bicleaner' ]; then
    url="https://github.com/bitextor/bicleaner-data/releases/latest/download"
    prefix=""
    extension="tar.gz"
    echo "### Downloading ${type} language pack ${url}"

    if invalid_url "${url}/${prefix}${SRC}-${TRG}.${extension}"; then
      echo "### ${SRC}-${TRG} language pack does not exist, trying ${TRG}-${SRC}..."
      if invalid_url "${url}/${prefix}${TRG}-${SRC}.${extension}"; then
        echo "### ${TRG}-${SRC} language pack does not exist"
        exit 1
      else
        lang1=$TRG
        lang2=$SRC
      fi
    else
      lang1=$SRC
      lang2=$TRG
    fi


    wget -P "${download_path}" "${url}/${prefix}${lang1}-${lang2}.${extension}"
    tar xvf "${download_path}/${prefix}${lang1}-${lang2}.${extension}" -C "${download_path}" --no-same-owner
    mv "${download_path}/${lang1}-${lang2}"/* "${download_path}/"
    rm "${download_path}/${prefix}${lang1}-${lang2}.${extension}"

else
  echo "Unsupported type: ${type}"
  exit 1
fi



echo "### ${type} language pack ${url} is downloaded"
