#!/bin/bash
##
# Downloads Tatoeba Challenge data (train, devset and eval in same package)
#

set -x
set -euo pipefail

echo "###### Downloading Tatoeba-Challenge data"

src=$1
trg=$2
output_prefix=$3
version=$4
max_sents=$5

tmp="$(dirname "${output_prefix}")/${version}"
mkdir -p "${tmp}"

archive_path="${tmp}/${version}-${src}-${trg}.tar"

#try both combinations of language codes 
if wget -O "${archive_path}" "https://object.pouta.csc.fi/Tatoeba-Challenge-${version}/${src}-${trg}.tar"; then
   package_src=${src}
   package_trg=${trg} 
elif wget -O "${archive_path}" "https://object.pouta.csc.fi/Tatoeba-Challenge-${version}/${trg}-${src}.tar"; then
   package_src=${trg}
   package_trg=${src}
fi

#extract all in same directory, saves the trouble of parsing directory structure
tar -xf "${archive_path}" --directory ${tmp} --strip-components 4 


# if max sents not -1, get the first n sents (this is mainly used for testing to make translation and training go faster)
if [ "${max_sents}" != "inf" ]; then
   head -${max_sents} <(pigz -dc "${tmp}/train.src.gz") | pigz > "${output_prefix}/train.${package_src}.gz"
   head -${max_sents} <(pigz -dc "${tmp}/train.trg.gz") | pigz > "${output_prefix}/train.${package_trg}.gz"
else
   mv ${tmp}/train.src.gz ${output_prefix}/train.${package_src}.gz   
   mv ${tmp}/train.trg.gz ${output_prefix}/train.${package_trg}.gz
fi

mv ${tmp}/train.id.gz ${output_prefix}/train.id.gz   

cat ${tmp}/dev.src | gzip > ${output_prefix}/dev.${package_src}.gz
cat ${tmp}/dev.trg | gzip > ${output_prefix}/dev.${package_trg}.gz

cat ${tmp}/test.src | gzip > ${output_prefix}/eval.${package_src}.gz
cat ${tmp}/test.trg | gzip > ${output_prefix}/eval.${package_trg}.gz

rm -rf "${tmp}"


echo "###### Done: Downloading Tatoeba-Challenge data"
