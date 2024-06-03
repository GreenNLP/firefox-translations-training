results = []

if train_student:
    results.extend([
        f'{experiment_dir}/config.yml',
        *expand(f'{eval_student_dir}/{{dataset}}.metrics',dataset=eval_datasets)
        ])

if quantize_student:
    results.extend([
        f'{exported_dir}/model.{src}{trg}.intgemm.alphas.bin.gz',
        f'{exported_dir}/lex.50.50.{src}{trg}.s2t.bin.gz',
        f'{exported_dir}/vocab.{src}{trg}.spm.gz',
        *expand(f'{eval_student_finetuned_dir}/{{dataset}}.metrics',dataset=eval_datasets),
        *expand(f'{eval_speed_dir}/{{dataset}}.metrics',dataset=eval_datasets)
    ])

#if rat:
    	

if wmt23_termtask:
    finetune_teacher_with_terms = wmt23_termtask.get('finetune-teacher-with-terms') 
    train_term_teacher = wmt23_termtask.get('train-term-teacher') 
    mixture_of_models = wmt23_termtask.get('mixture-of-models')

    annotation_schemes = wmt23_termtask['annotation-schemes']
    term_ratios = wmt23_termtask['term-ratios']
    sents_per_term_sents = wmt23_termtask['sents-per-term-sents']

    #results.extend(expand(f'{eval_res_dir}/teacher-base0-{{ens}}/wmt23_termtask.score',ens=ensemble))
    results.extend(expand(f'{eval_res_dir}/teacher-base0-{{ens}}/evalsets_terms.score',ens=ensemble))
    results.extend(expand(f'{eval_res_dir}/teacher-base0-{{ens}}/evalsets_terms.noterms.score',ens=ensemble))

    if finetune_teacher_with_terms: 
        #results.extend(expand(f'{eval_res_dir}/teacher-base-finetuned-term-{{annotation_scheme}}-{{term_ratio}}-{{sents_per_term_sent}}{{omit}}/wmt23_termtask.score',
        #    annotation_scheme=annotation_schemes,
        #    term_ratio=term_ratios,
        #    sents_per_term_sent=sents_per_term_sents,
        #    omit=omit_unannotated))

        #results.extend(expand(f'{eval_res_dir}/teacher-base-finetuned-term-{{annotation_scheme}}-{{term_ratio}}-{{sents_per_term_sent}}{{omit}}/evalsets_terms.score',
        #    annotation_scheme=annotation_schemes,
        #    term_ratio=term_ratios,
        #    sents_per_term_sent=sents_per_term_sents,
        #    omit=omit_unannotated))

        results.extend(expand(f'{eval_res_dir}/teacher-base-finetuned-term-{{annotation_scheme}}-{{term_ratio}}-{{sents_per_term_sent}}{{omit}}/evalsets_terms.score',
            annotation_scheme=annotation_schemes,
            term_ratio=term_ratios,
            sents_per_term_sent=sents_per_term_sents,
            omit=omit_unannotated))
        
        results.extend(expand(f'{eval_res_dir}/teacher-base-finetuned-term-{{annotation_scheme}}-{{term_ratio}}-{{sents_per_term_sent}}{{omit}}/evalsets_terms.noterms.score',
            annotation_scheme=annotation_schemes,
            term_ratio=term_ratios,
            sents_per_term_sent=sents_per_term_sents,
            omit=omit_unannotated))

	results.extend(expand(f'{eval_res_dir}/teacher-base-finetuned-term-{{annotation_scheme}}-{{term_ratio}}-{{sents_per_term_sent}}{{omit}}/{{dataset}}.metrics',
            annotation_scheme=annotation_schemes,
            term_ratio=term_ratios,
            sents_per_term_sent=sents_per_term_sents,
            omit=omit_unannotated,
            dataset=eval_datasets))

    if mixture_of_models:
        mixture_hash = hashlib.md5(("+".join(mixture_of_models)).encode("utf-8")).hexdigest()
        #results.extend(expand(f'{eval_res_dir}/mixture-{mixture_hash}/testset_terms.mixture.{trg}'))
        #results.extend(expand(f'{eval_res_dir}/mixture-{mixture_hash}/blindset_terms.mixture.{trg}'))
        results.extend(expand(f'{eval_res_dir}/mixture-{mixture_hash}/evalsets_terms.mixture.{trg}'))
    else:
        mixture_hash = None    

    if train_term_teacher:
#            results.extend(expand(f'{eval_res_dir}/teacher-base-term-{{annotation_scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/wmt23_termtask.score',
#                annotation_scheme=annotation_schemes,
#                term_ratio=term_ratios,
#                sents_per_term_sent=sents_per_term_sents))

        results.extend(expand(f'{eval_res_dir}/teacher-base-term-{{annotation_scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/{{dataset}}.metrics',
            annotation_scheme=annotation_schemes,
            term_ratio=term_ratios,
            sents_per_term_sent=sents_per_term_sents,dataset=eval_datasets))


    if train_student:
        results.extend([f'{eval_student_dir}/wmt23_termtask.score'])
        
        results.extend(expand(f'{eval_student_dir}-term-{{annotation_scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/wmt23_termtask.score',
            annotation_scheme=annotation_schemes,
            term_ratio=term_ratios,
            sents_per_term_sent=sents_per_term_sents))

        results.extend(expand(f'{eval_student_dir}-term-{{annotation_scheme}}-{{term_ratio}}-{{sents_per_term_sent}}/{{dataset}}.metrics',
            annotation_scheme=annotation_schemes,
            term_ratio=term_ratios,
            sents_per_term_sent=sents_per_term_sents,dataset=eval_datasets))
         


results.extend(expand(f'{eval_res_dir}/teacher-base0-{{ens}}/{{dataset}}.metrics',ens=ensemble, dataset=eval_datasets))

if len(ensemble) > 1:
    results.extend(expand(f'{eval_teacher_ens_dir}/{{dataset}}.metrics', dataset=eval_datasets))

if install_deps:
    results.append("/tmp/flags/setup.done")

#three options for backward model: pretrained path, url to opus-mt, or train backward
if backward_pretrained:
    do_train_backward = False
    backward_dir = backward_pretrained
elif opusmt_backward:
    do_train_backward = False 
else:
    # don't evaluate pretrained model
    if train_student:
        results.extend(expand(f'{eval_backward_dir}/{{dataset}}.metrics',dataset=eval_datasets))
        do_train_backward=True
    else:
        do_train_backward=False
