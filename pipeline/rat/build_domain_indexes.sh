#!/bin/bash

# Function to display usage/help message
usage() {
    echo "Usage: $0 <source_file> <target_file> <origin_file> <fuzzy_match_cli>"
    echo
    echo "Arguments:"
    echo "  <source_file>        Path to the file containing source language sentences."
    echo "  <target_file>        Path to the file containing parallel target language sentences."
    echo "  <origin_file>        Path to the tab-separated file containing origins and other fields."
    echo "  <fuzzy_match_cli>    Path to the executable that will be used for building the fuzzy index."
    echo "  <output_dir>    Path where to output the fuzzy indexes."
}

# Check if the required number of arguments is provided
if [ "$#" -ne 5 ]; then
    usage
    exit 1
fi

# Input arguments
fuzzy_match_cli="$1"
source_file="$2"
target_file="$3"
origin_file="$4"
output_dir="$5"

# Temporary directory to store the split files
tmp_dir="${output_dir}/tmp"
mkdir -p $tmp_dir
# trap 'rm -rf "$tmp_dir"' EXIT

# Initialize an array to keep track of unique origins
declare -A origins_seen

# Read through the gzipped origin, source, and target files and split by origin
paste <(zcat "$source_file") <(zcat "$target_file") <(zcat "$origin_file") | \
while IFS=$'\t' read -r src_line trg_line origin _ _; do
    # Define paths for origin-based files
    src_out="${tmp_dir}/${origin}_source.txt"
    trg_out="${tmp_dir}/${origin}_target.txt"

    # Append lines to appropriate origin-based files
    echo "$src_line" >> "$src_out"
    echo "$trg_line" >> "$trg_out"

    # Track the unique origin
    origins_seen["$origin"]=1
done

# Now iterate over the collected unique origins
for origin in "${!origins_seen[@]}"; do

	# Skip crawled corpora
    if [[ "$origin" =~ ^(CCMatrix|NLLB|ParaCrawl|HPLT|CCAligned|XLEnt) ]]; then
        continue
    fi

    # Define source and target language files for this origin
    src_corpus="${tmp_dir}/${origin}_source.txt"
    trg_corpus="${tmp_dir}/${origin}_target.txt"

    # Run the provided fuzzy match command for this pair
    "${fuzzy_match_cli}" --action index --corpus "${src_corpus},${trg_corpus}" --add-target

    # Move the index to the output directory
    mv "${src_corpus}.fmi" ${output_dir}
done

