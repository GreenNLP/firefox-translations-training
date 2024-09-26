#!/usr/bin/env python3
import re
import sys
import subprocess as sp
import os
import yaml

from snakemake.utils import read_job_properties
from snakemake.logging import logger

cluster_config_file = os.path.join(os.path.dirname(__file__), "config.cluster.yaml")
cluster_config = yaml.load(open(cluster_config_file), Loader=yaml.FullLoader)

jobscript = sys.argv[-1]
job_properties = read_job_properties(jobscript)

options = []

if job_properties["type"] == 'single':
    name = job_properties['rule']
elif job_properties["type"] == 'group':
    name = job_properties['groupid']
else:
    raise NotImplementedError(f"Don't know what to do with job_properties['type']=={job_properties['type']}")

options += ['--job-name', name]

account = cluster_config['cpu-account']

if "resources" in job_properties:
    resources = job_properties["resources"]

    if 'gpu' in resources and int(resources['gpu']) >= 1:
        num_gpu = str(resources['gpu'])
        #options += [f'--gres=gpu:v100:{num_gpu}']
        options += [f'--gpus={num_gpu}']
        account = cluster_config['gpu-account']

        if num_gpu == '1':
            partition = cluster_config['single-gpu-partition']
        else:
            partition = cluster_config['multi-gpu-partition']
        rocm_dir = os.getenv("ROCM_PATH") 
        options += ['--export', f'ALL,SINGULARITY_BIND="{rocm_dir}"']
    else:
        #this is a LUMI-C job 
        if 'threads' in job_properties and int(job_properties['threads']) >= 128:
            if 'mem_mb' in resources and int(resources['mem_mb'] < 256000):
                partition = cluster_config['fullnode-cpu-partition']
            else:
                partition = cluster_config['partialnode-cpu-partition'] # The LUMI-C nodes with more memory than 256GB are in small partition
        else:
            partition = cluster_config['partialnode-cpu-partition']

    # we don't need explicit memory limiting for now
    if 'mem_mb' in resources:
        memory = str(resources['mem_mb']) 
        options += [f'--mem={memory}']


options += ['-p', partition]
options += ['-A', account]
options += ['--nodes=1']
options += ['-t', str(cluster_config['time-limit'])]

if "threads" in job_properties:
    options += ["--cpus-per-task", str(job_properties["threads"])]

try:
    #cmd = ["sbatch"] + ["--parsable"] + options + [f"--wrap=\"/bin/bash -c '{jobscript}'\""]
    cmd = ["sbatch"] + ["--parsable"] + options + [jobscript]
    logger.info(f'Running command: {cmd}')
    res = sp.check_output(cmd)
except sp.CalledProcessError as e:
    raise e
# Get jobid
res = res.decode()
try:
    jobid = re.search(r"(\d+)", res).group(1)
except Exception as e:
    raise e

print(jobid)