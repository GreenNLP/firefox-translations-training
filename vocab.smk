wildcard_constraints:
    src="\w{2,3}",
    trg="\w{2,3}",
    vocab_size="\d+"

rule train_joint_spm_vocab:
    message: "Training spm vocab"
    log: "{project_name}/{src}-{trg}/{preprocessing}/train_joint_spm_vocab_{vocab_size}_{prepend_spaces}/train_joint_spm_vocab.log"
    conda: "envs/base.yml"
    threads: 2
    input:
        spm_train=ancient(config["spm-train"]),
        source="{project_name}/{src}-{trg}/{preprocessing}/train.{src}.gz",
        target="{project_name}/{src}-{trg}/{preprocessing}/train.{trg}.gz"
    output:
        vocab="{project_name}/{src}-{trg}/{preprocessing}/train_joint_spm_vocab_{vocab_size}_{prepend_spaces}/vocab.spm"
    shell: f'''bash pipeline/train/spm-vocab.sh "{{input.source}}" "{{input.target}}" "{{output.vocab}}" {config["spm-sample-size"]} {{threads}} {{wildcards.vocab_size}} {config["user-defined-symbols"]} "{{input.spm_train}}" "{{wildcards.prepend_spaces}}" >> {{log}} 2>&1'''
