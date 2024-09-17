# Basic Usage

The pipeline is built using [Snakemake](https://snakemake.readthedocs.io/en/stable/).

Snakemake is a workflow management system that implicitly constructs a Directed Acyclic Graph (DAG) of tasks based on the input and output files specified in each step. It determines which files are missing and executes the corresponding jobs, either locally or on a cluster, depending on the configuration. Snakemake can also parallelize steps that can be run concurrently.

The main Snakemake process (scheduler) should be launched interactively. It manages the job execution either on worker nodes in a cluster (cluster mode) or on a local machine (local mode).

## Configuration Examples

The pipeline is executed using the provided [Makefile](https://github.com/Helsinki-NLP/OpusDistillery/blob/main/Makefile), which takes a configuration file as input. Configuration files are written in [YAML](https://yaml.org/) format. You can find more details on configuration in the [Setting up your experiment](configs/downloading_and_selecting_data.md) section. Below is an example configuration file that trains a student model for Estonian, Finnish, and Hungarian into English:

```yaml

experiment:
  dirname: test
  name: fiu-eng
  langpairs:
    - et-en
    - fi-en
    - hu-en

  #URL to the OPUS-MT model to use as the teacher
  opusmt-teacher: "https://object.pouta.csc.fi/Tatoeba-MT-models/fiu-eng/opus4m-2020-08-12.zip"

  #URL to the OPUS-MT model to use as the backward model
  opusmt-backward: "https://object.pouta.csc.fi/Tatoeba-MT-models/eng-fiu/opus2m-2020-08-01.zip"
  one2many-backward: True
  
  parallel-max-sentences: 10000000
  split-length: 1000000

  best-model: perplexity

datasets:
  train:
    - tc_Tatoeba-Challenge-v2023-09-26
  devtest:
    - flores_dev
  test:
    - flores_devtest
```

## Running

To check that everything is installed correctly, run a dry run first:

```
make dry-run
```

To execute the full pipeline, specify a specific profile and configuration file:

```
make run PROFILE=slurm-puhti CONFIG=configs/config.test.yml
```

### Specific target

By default, all Snakemake rules are executed. To run the pipeline up to a specific rule, use:

```
make run TARGET=<non-wildcard-rule-or-path>
```

For example,  to collect the corpus first:

```
make run TARGET=merge_corpus
```

You can also specify the full file path, such as:

```
make run TARGET=/models/ru-en/bicleaner/teacher-base0/model.npz.best-ce-mean-words.npz
```
### Rerunning

If you need to rerun a specific step, delete the output files expected in the Snakemake rule.
If Snakemake reports a missing file and suggests running with the `--clean-metadata` flag, do the following:

```
make clean-meta TARGET=<missing-file-name>
```
and then as usual:

```
make run PROFILE=<profile> CONFIG=<configuration-file>
```

### Canceling

If you need to cancel a running pipeline on a cluster, remember to also cancel the associated SLURM jobs, as these will not be canceled automatically.
Additionally, delete any resulting files that you want to overwrite.

### On LUMI

To run the pipeline on LUMI, start from the login node using your local copy of the root repository.

First, start a tmux session. You can read more about [tmux](https://github.com/tmux/tmux/wiki) here.

Load the LUMI-specific modules:

```bash
module load CrayEnv
module load PrgEnv-cray/8.3.3
module load craype-accel-amd-gfx90a
module load cray-python
module load rocm/5.3.3
export SINGULARITYENV_LD_LIBRARY_PATH=$LD_LIBRARY_PATH
```

Activate the Snakemake environment:

```bash
source ../snakemake_env/bin/activate
```
You can now proceed as explained above.