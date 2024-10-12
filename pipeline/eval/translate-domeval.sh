#!/bin/bash

##
# Evaluate a model with domain data.
#

set -x
set -euo pipefail

echo "###### Evaluation of a model"

data_directory=$1
result_directory=$2
src=$3
trg=$4
marian_decoder=$5
decoder_config=$6
model_dir=$(dirname "${decoder_config}")
model_step=$(basename "${model_dir}")
args=( "${@:7}" )

mkdir -p "$(basename "${result_directory}")"

translate() {
    local source_file=$1
    local output_file=$2
	if [[ "${model_step}" == *opus* ]]; then
	  source_spm_path="${model_dir}/source.spm"
	  target_spm_path="${model_dir}/target.spm"
	  sp_source_file="${source_file}.sp}"
	  cat "${source_file}" | "${MARIAN}/spm_encode" --model "${source_spm_path}" > "${sp_source_file}" 
	  source_file=$sp_source_file
	fi
        echo "Translating $source_file to $output_file..."
        "${marian_decoder}" \
          -c "${decoder_config}" \
          --input "${source_file}" \
          --quiet \
          --quiet-translation \
          --log "${output_file}.log" \
          "${args[@]}" > "${output_file}"
	
	if [[ "${model_step}" == *opus* ]]; then
	  sp_output_file="${output_file}.sp"
	  mv "${output_file}" "${sp_output_file}"
	  "${MARIAN}/spm_decode" --model "${target_spm_path}" < "${sp_output_file}" > "${output_file}" 
	fi

}

domeval_dir="$result_directory"

# Create the domeval subdirectory in the output directory
mkdir -p "$domeval_dir"

# First find all files matching the pattern in the directory
files=$(find "$data_directory" -type f -name "*-domeval.${src}.gz")

# Remove FUZZY_BREAK tokens, save as gzipped nofuzzies.trans, and run translate on the nofuzzies file for the first file
first_file=$(echo "$files" | head -n 1)
first_file_basename=$(basename ${first_file} .${src}.gz)
gunzip -c "$first_file" | sed 's/.*FUZZY_BREAK //' > "$domeval_dir/nofuzzies.${src}"

translate "$domeval_dir/nofuzzies.${src}" "$domeval_dir/nofuzzies.${trg}"

#create ref file
ref_file="${domeval_dir}/domeval.${trg}.ref"
zcat "${data_directory}/${first_file_basename}.${trg}.gz" > ${ref_file}

# Translate domeval with non-domain specific train and all_filtered indexes


# Iterate over each file found in the directory
for file in $files; do
    basename=$(basename "$file" .${src}.gz)
    fuzzies_file="$domeval_dir/${basename}.fuzzies"
    line_numbers_file="$domeval_dir/${basename}.linenum"
    translated_fuzzies_file="$domeval_dir/${basename}.translated_fuzzies"

    # Separate lines containing FUZZY_BREAK into .fuzzies file and store their line numbers
    gunzip -c "$file" | grep -n 'FUZZY_BREAK' > "$line_numbers_file"

    # Extract only the FUZZY_BREAK lines into the .fuzzies file and gzip the result
    cut -d: -f2- "$line_numbers_file" > "$fuzzies_file"

    # Run translate on the fuzzies file and generate the translated fuzzies file
    translate "$fuzzies_file" "$translated_fuzzies_file"

    # Create the output file for this input file
    output_file="$domeval_dir/${basename}.${trg}"

    python pipeline/eval/merge_domain_translations.py $"$domeval_dir/nofuzzies.${trg}" "$translated_fuzzies_file" "${line_numbers_file}" "${output_file}"

    echo "Created merged output for $file as $output_file"
done
