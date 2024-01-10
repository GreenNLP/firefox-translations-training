#!/bin/bash
#SBATCH --job-name="marian_%j.sh"
#SBATCH --account=project_2005815
#SBATCH --output=logs/marian_%j.out
#SBATCH --error=logs/marian_%j.err
#SBATCH --time=72:00:00
#SBATCH --partition=gpu
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --gres=gpu:v100:1
#SBATCH --cpus-per-task=10
#SBATCH --mem-per-cpu=1000

# Author: Ona de Gibert Bonet
# Datestamp: 14-12-2023
# Usage: bash scripts/validate.sh valid_logs data/devset.et-en.tsv data/devset.fi-en.tsv data/devset.hu-en.tsv
# Make sure you have matplotlib installed

valid_dir="$1"
# Sort valid logs according to their creation time
sorted_valid_logs=($(stat -c "%Y %n" "${valid_dir}"/*txt | sort -n | cut -d' ' -f2))

ref_paths=( "${@:2}" )
# Sort files in alphabetical order
sorted_ref_paths=($(ls -1 "${ref_paths[@]}" | sort))

idx=0

for data_path in "${sorted_ref_paths[@]}"; do
    file_name="devset"
    lang_pair=$(echo "$data_path"  | grep -oE "\b[a-z]{2}-[a-z]{2}\b")
    base_name="${file_name}.${lang_pair}"

    echo "Computing statistics for ${lang_pair}..."
    if [ -e $valid_dir/"${base_name}.valid.bleu.log" ]; then
        echo "Output logs already exists. Remove exististing logs to overwrite."
    else

        if [[ "${data_path}" == *.tsv ]]; then
            awk -F'\t' '{print $2}' "${data_path}" > ref
        elif [[ "${data_path}" == *.gz ]]; then
            zcat "${data_path}" > ref
        else
            cat "${data_path}" > ref
        fi

        lines=$(wc -l < ref)
        length=$((idx + lines))

        for file in "${sorted_valid_logs[@]}"; do
            filename=$(basename "${file}")
        
            head -n "${length}" "${file}" | tail -n "${lines}" > tmp
            sacrebleu ref -i tmp -m bleu --score-only >> $valid_dir/"${base_name}.valid.bleu.log"
            sacrebleu ref -i tmp -m chrf --score-only >> $valid_dir/"${base_name}.valid.chrf.log"
            sacrebleu ref -i tmp -m ter --score-only >> $valid_dir/"${base_name}.valid.ter.log"
            echo "File ${filename} has been processed ✓"

            if [ $idx -eq 0 ]; then

                # Extract updates and epochs using regex
                updates="${filename##*after-}"
                updates="${updates%%-*}"

                epochs="${filename##*updates-}"
                epochs="${epochs%%-epochs*}"
                echo "${updates}" >> $valid_dir/updates.log
                echo "${epochs}" >> $valid_dir/epochs.log
            fi
        done
        idx=$((idx + length))
    fi
    rm tmp
    rm ref
    
    # Plot figures
    
    #python scripts/plot_valid_curves.py $valid_dir/"${base_name}.valid"
done

#python scripts/plot_bleu_all_pairs.py $valid_