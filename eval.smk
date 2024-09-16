wildcard_constraints:
    src="\w{2,3}",
    trg="\w{2,3}",
    train_vocab="train_joint_spm_vocab[^/]+",
    learn_rate="\d+"

gpus_num=config["gpus-num"]

#TODO: combine model evaluation rules by storing vocabs in model dir with normally trained models as well
rule evaluate_opus_model:
    message: "Evaluating an OPUS model"
    log: "{datadir}/{project_name}/{src}-{trg}/{preprocessing}/finetune_{learn_rate}_{model_name}/eval/evaluate_{modeltype}{dataset}.log"
    conda: "envs/base.yml"
    threads: 7
    resources: gpu=1
    priority: 50
    wildcard_constraints:
        modeltype="(basemodel-|)"
    input:
        ancient(config["marian-decoder"]),
        eval_source='{datadir}/{project_name}/{src}-{trg}/{preprocessing}/{dataset}.{src}.gz',
        eval_target='{datadir}/{project_name}/{src}-{trg}/{preprocessing}/{dataset}.{trg}.gz',
        model=f'{{datadir}}/{{project_name}}/{{src}}-{{trg}}/{{preprocessing}}/finetune_{{learn_rate}}_{{model_name}}/final.model.npz.best-{config["best-model-metric"]}.npz'
    output:
        report('{datadir}/{project_name}/{src}-{trg}/{preprocessing}/finetune_{learn_rate}_{model_name}/eval/{modeltype}{dataset}.metrics',
            category='evaluation', subcategory='{model}', caption='reports/evaluation.rst')
    params:
        dataset_prefix='{datadir}/{project_name}/{src}-{trg}/{preprocessing}/{dataset}',
        res_prefix='{datadir}/{project_name}/{src}-{trg}/{preprocessing}/finetune_{learn_rate}_{model_name}/eval/{modeltype}{dataset}',
        decoder_config=
            lambda wildcards: f'{wildcards.datadir}/models/{wildcards.src}-{wildcards.trg}/{wildcards.model_name}/decoder.yml' if wildcards.modeltype=="basemodel-" else f'{wildcards.datadir}/{wildcards.project_name}/{wildcards.src}-{wildcards.trg}/{wildcards.preprocessing}/finetune_{wildcards.learn_rate}_{wildcards.model_name}/final.model.npz.best-{config["best-model-metric"]}.npz.decoder.yml',
    	decoder=config["marian-decoder"]
    shell: '''bash pipeline/eval/eval-gpu.sh "{params.res_prefix}" "{params.dataset_prefix}" {wildcards.src} {wildcards.trg} {params.decoder} "{params.decoder_config}" >> {log} 2>&1'''



rule evaluate:
    message: "Evaluating a model"
    log: "{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/train_model_{model_type}-{training_type}/eval/evaluate_{dataset}.log"
    conda: "envs/base.yml"
    threads: 7
    resources: gpu=1
    priority: 50
    wildcard_constraints:
        model="[\w-]+"
    input:
        ancient(config["marian-decoder"]),
        eval_source='{project_name}/{src}-{trg}/{preprocessing}/{dataset}.{src}.gz',
        eval_target='{project_name}/{src}-{trg}/{preprocessing}/{dataset}.{trg}.gz',
        src_spm='{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/vocab.spm',
        trg_spm='{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/vocab.spm',
    	model=f'{{project_name}}/{{src}}-{{trg}}/{{preprocessing}}/{{train_vocab}}/train_model_{{model_type}}-{{training_type}}/final.model.npz.best-{config["best-model-metric"]}.npz'
    output:
        report('{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/train_model_{model_type}-{training_type}/eval/{dataset}.metrics',
            category='evaluation', subcategory='{model}', caption='reports/evaluation.rst')
    params:
        dataset_prefix='{project_name}/{src}-{trg}/{preprocessing}/{dataset}',
        res_prefix='{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/train_model_{model_type}-{training_type}/eval/{dataset}',
        src_lng=lambda wildcards: wildcards.src if "backward" not in wildcards.model_type else wildcards.trg,
        trg_lng=lambda wildcards: wildcards.trg if "backward" not in wildcards.model_type else wildcards.src,
        decoder_config=f'{{project_name}}/{{src}}-{{trg}}/{{preprocessing}}/{{train_vocab}}/train_model_{{model_type}}-{{training_type}}/final.model.npz.best-{config["best-model-metric"]}.npz.decoder.yml',
	decoder=config["marian-decoder"]
    shell: '''bash pipeline/eval/eval-gpu.sh "{params.res_prefix}" "{params.dataset_prefix}" {params.src_lng} {params.trg_lng} {params.decoder} "{params.decoder_config}" >> {log} 2>&1'''


rule evaluate_ct2:
    message: "Evaluating a model using ctranslate2"
    log: "{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/train_model_{model_type}-{training_type}/eval/evaluate_ct2_{dataset}.log"
    #conda: "envs/base.yml"
    conda: None
    container: None
    threads: workflow.cores
    #resources: gpu=1
    priority: 50
    wildcard_constraints:
        model="[\w-]+"
    input:
        ancient(config["marian-decoder"]),
        eval_source='{project_name}/{src}-{trg}/{preprocessing}/{dataset}.{src}.gz',
        eval_target='{project_name}/{src}-{trg}/{preprocessing}/{dataset}.{trg}.gz',
        src_spm='{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/vocab.spm',
        trg_spm='{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/vocab.spm',
    	model='{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/train_model_{model_type}-{training_type}/ct2_conversion/model.bin'
    output:
        report('{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/train_model_{model_type}-{training_type}/eval/{dataset}.ct2.metrics',
            category='evaluation', subcategory='{model}', caption='reports/evaluation.rst')
    params:
        dataset_prefix='{project_name}/{src}-{trg}/{preprocessing}/{dataset}',
        res_prefix='{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/train_model_{model_type}-{training_type}/eval/{dataset}',
        src_lng=lambda wildcards: wildcards.src if "backward" not in wildcards.model_type else wildcards.trg,
        trg_lng=lambda wildcards: wildcards.trg if "backward" not in wildcards.model_type else wildcards.src,
        ct2_model_dir='{project_name}/{src}-{trg}/{preprocessing}/{train_vocab}/train_model_{model_type}-{training_type}/ct2_conversion'
    shell: '''bash pipeline/eval/eval-ct2.sh "{params.res_prefix}" "{params.dataset_prefix}" {params.src_lng} {params.trg_lng} {params.ct2_model_dir} "{input.src_spm}" {threads} 1 >> {log} 2>&1'''
