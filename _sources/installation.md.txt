# Installation

## Getting started on CSC's puhti and mahti
1. Clone the repository.
2. Download the Ftt.sif container to the repository root.
3. Create a virtual Python environment for Snakemake (e.g. in the parent dir of the repository):
    1. The environment needs to be created with a non-containerized python, as otherwise Apptainer integration will not work. On puhti and mahti, the python executables in /usr/bin/ should work: `/usr/bin/python3.9 -m venv snakemake_env`.
    2. Activate the virtual environment: `source ./snakemake_env/bin/activate`.
    3. Install snakemake: `pip install snakemake`.
4. Install micromamba (e.g. in the parent dir of the repository): `curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest | tar -xvj bin/micromamba`
5. Return to the repository directory and update Git submodules: `make git-modules`
6. Create a _data_ directory (e.g. in the parent dir of the repository) and create a _tmp_ dir in it.
7. If the data directory is not located in the parent directory of the repository, edit _profiles/slurm-puhti/config.yaml_ or _profiles/slurm-mahti/config.yaml_ and change the bindings in the singularity-args section to point to your data directory, and also enter the _data_ directory path as the _root_ value of the _config_ section.
8. Edit profiles/slurm-puhti/config.cluster.yaml to change the CSC account to one you have access to. 
9. Load cuda modules: module load gcc/9.4.0 cuda cudnn
10. Run pipeline: `make run-hpc PROFILE="slurm-puhti"` or `make run PROFILE="slurm-mahti"`. More information in [Basic Usage](usage.md).

## Getting started on CSC's lumi
1. Clone the repository.
2. Download the Ftt.sif container to the repository root.
3. Create a virtual Python environment for Snakemake (e.g. in the parent dir of the repository):
    1. The environment needs to be created with a non-containerized python, as otherwise Apptainer integration will not work. On lumi, use the _cray-python_ module (it is not containerized): `module load cray-python; python -m venv snakemake_env`.
    2. Activate the virtual environment: `source ./snakemake_env/bin/activate`.
    3. Install snakemake: `pip install snakemake`.
4. Install micromamba (e.g. in the parent dir of the repository): `curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest | tar -xvj bin/micromamba`
5. Return to the repository directory and update Git submodules: `make git-modules`
6. Create a _data_ directory (e.g. in the parent dir of the repository) and create a _tmp_ dir in it.
7. If the data directory is not located in the parent directory of the repository, edit profiles/slurm-lumi/config.yaml and change the bindings in the singularity-args section to point to your data directory, and also enter the _data_ directory path as the _root_ value of the _config_ section.
8. Edit profiles/slurm-puhti/config.cluster.yaml to change the CSC account to one you have access to. 
9. Load rocm module: module load rocm.
10. Copy the marian executables to _3rd_party/lumi-marian/build_ (compiling lumi-marian is currently hacky, so this workaround makes things easier).
11. Enter _export SINGULARITYENV_LD_LIBRARY_PATH=$LD_LIBRARY_PATH_ to make sure Marian can find all the libraries when it runs containerized.
12. Run pipeline: `make run-hpc PROFILE="slurm-lumi"`.  More information in [Basic Usage](usage.md).