# Basic usage

The pipeline is built with [Snakemake](https://snakemake.readthedocs.io/en/stable/).

Snakemake workflow manager infers the DAG of tasks implicitly from the specified inputs and outputs of the steps. The workflow manager checks which files are missing and runs the corresponding jobs either locally or on a cluster depending on the configuration.

Snakemake parallelizes steps that can be executed simultaneously.

The main Snakemake process (scheduler) should be launched interactively. It runs the job processes on the worker nodes in cluster mode or on a local machine in local mode.

## Configuration examples

The pipeline is run with the [Makefile](https://github.com/Helsinki-NLP/OpusDistillery/blob/multi-ftt/Makefile) which takes a configuration file as an input. 
Configuration files are in [YAML](https://yaml.org/) format. Although we report details of the configuration files in [Setting up your experiment](configs/downloading_and_selecting_data.md), a configuration file that trains a student model (Estonian, Finnish and Hungarian into English) looks like this:

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

### On LUMI

On LUMI, the pipeline is run from the login node from your local copy of the root repository.

Start a tmux session: `tmux`
You can read more about [tmux](https://github.com/tmux/tmux/wiki) here.

Load LUMI specific modules:

```bash
module load CrayEnv
module load PrgEnv-cray/8.3.3
module load craype-accel-amd-gfx90a
module load cray-python
module load rocm/5.3.3
export SINGULARITYENV_LD_LIBRARY_PATH=$LD_LIBRARY_PATH
```

Activate snakemake environment:

```bash
source ../snakemake_env/bin/activate
```

Now, you can move on and continue to the next section.

### Usual run

Dry run first to check that everything was installed correctly:

```
make dry-run
```

To run the pipeline:
```
make run
```

To test the whole pipeline end to end (it is supposed to run relatively quickly and does not train anything useful):

```
make test
```
You can also run a specific profile or config by overriding variables from Makefile
```
make run PROFILE=slurm-puhti CONFIG=configs/config.test.yml
```

### Specific target

By default, all Snakemake rules are executed. To run the pipeline up to a specific rule use:
```
make run TARGET=<non-wildcard-rule-or-path>
```
For example, collect corpus first:
```
make run TARGET=merge_corpus
```

You can also use the full file path, for example:
```
make run TARGET=/models/ru-en/bicleaner/teacher-base0/model.npz.best-ce-mean-words.npz
```
### Rerunning

If you want to rerun a specific step or steps, you can delete the result files that are expected in the Snakemake rule output.
Snakemake might complain about a missing file and suggest to run it with `--clean-metadata` flag. In this case run:
```
make clean-meta TARGET=<missing-file-name>
```
and then as usual:
```
make run
```