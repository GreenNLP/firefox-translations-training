#!/bin/bash

src_vocab=$1
trg_vocab=$2
src=$3
trg=$4
evalsets_src=$5
evalsets_trg=$6
evalsets_aln=$7
evalsets_terms_src_gz=$8
evalsets_terms_trg_gz=$9}
evalsets_terms_aln_gz=${10}
evalsets_sgm_src=${11}
evalsets_sgm_trg=${12}
evalsets_terms_src_gz=${13}
evalsets_terms_src=${14}
evalsets_terms_trg_gz=${15}
evalsets_terms_trg=${16}
evalsets_terms_aln_gz=${17}
evalsets_terms_aln=${18}

python 3rd_party/soft-term-constraints/src/softconstraint.py \
  --source_spm "${src_vocab}" --target_spm "${trg_vocab}"  \
  --term_start_tag augmentsymbol0 --term_end_tag augmentsymbol1 --trans_end_tag augmentsymbol2 \
  --mask_tag augmentsymbol3 --source_lang "${src}" --target_lang "${trg}" \
  --source_corpus "${evalsets_src}" --target_corpus "${evalsets_trg}" \
  --alignment_file "${evalsets_aln}" --omit_unannotated \
  --source_output_path "${evalsets_terms_src_gz}" --target_output_path "${evalsets_terms_trg_gz}" \
  --alignment_output_path "${evalsets_terms_aln_gz}" \
  --source_sgm_path "${evalsets_sgm_src}" \
  --sp_output --sp_input \
  --target_sgm_path "${evalsets_sgm_trg}" &&
zcat "${evalsets_terms_src_gz}" > "${evalsets_terms_src}" &&
zcat "${evalsets_terms_trg_gz}" > "${evalsets_terms_trg}" &&
zcat "${evalsets_terms_aln_gz}" > "${evalsets_terms_aln}"
