#!/bin/bash
#SBATCH --job-name="valid_curves_%j.sh"
#SBATCH --account=project_462000447
#SBATCH --output=logs/valid_curves_%j.out
#SBATCH --error=logs/valid_curves_%j.err
#SBATCH --time=00:30:00
#SBATCH --partition=dev-g
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --gpus-per-node=1

# Author: Ona de Gibert Bonet
# Datestamp: 14-12-2023
# Usage: bash scripts/validate.sh valid_logs data/devset.et-en.tsv data/devset.fi-en.tsv data/devset.hu-en.tsv
# Make sure you have matplotlib installed

module load cray-python
source /scratch/project_462000088/members/degibert/data/logs/dashboard/dashboard_venv/bin/activate

valid_dir="$1"
session="${2//\//_}"    
# Sort valid logs according to their creation time
sorted_valid_logs=($(stat -c "%Y %n" "${valid_dir}"/*txt | sort -n | cut -d' ' -f2))

ref_paths=( "${@:3}" )
# Sort files in alphabetical order
sorted_ref_paths=($(ls -1 "${ref_paths[@]}" | sort))

idx=0

echo "Parsing session: $2"

for data_path in "${sorted_ref_paths[@]}"; do
    file_name="devset"
    lang_pair=$(echo "$data_path"  | grep -oE "\b[a-z]{2}-[a-z]{2}\b")
    base_name="${file_name}.${lang_pair}"

    echo "Computing statistics for ${lang_pair}..."
    if [ -e $valid_dir/"${base_name}.valid.bleu.log" ]; then
        echo "Output logs already exists. Remove exististing logs to overwrite."
    else

        if [[ "${data_path}" == *.tsv ]]; then
            awk -F'\t' '{print $2}' "${data_path}" > ref_$session
        elif [[ "${data_path}" == *.gz ]]; then
            zcat "${data_path}" > ref_$session
        else
            cat "${data_path}" > ref_$session
        fi

        lines=$(wc -l < ref_$session)
        length=$((idx + lines))

        for file in "${sorted_valid_logs[@]}"; do
            filename=$(basename "${file}")
        
            head -n "${length}" "${file}" | tail -n "${lines}" > tmp_$session
            sacrebleu ref_$session -i tmp_$session -m bleu --score-only >> $valid_dir/"${base_name}.valid.bleu.log"
            sacrebleu ref_$session -i tmp_$session -m chrf --score-only >> $valid_dir/"${base_name}.valid.chrf.log"
            sacrebleu ref_$session -i tmp_$session -m ter --score-only >> $valid_dir/"${base_name}.valid.ter.log"
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
    rm tmp_$session
    rm ref_$session
    
    # Plot figures
    
    #python plot_valid_curves.py $valid_dir/"${base_name}.valid"
done

#Generate plots

if [ -e "$valid_dir/bleu_all_pairs.png" ]; then
    echo "Image already exists. Remove to overwrite"
else
    python plot_bleu_all_pairs.py $valid_dir
fi

cp $valid_dir/bleu_all_pairs.png /scratch/project_462000088/members/degibert/data/logs/images/$session.png
