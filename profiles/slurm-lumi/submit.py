#!/usr/bin/env python3
import re
import sys
import subprocess as sp
import os
import yaml
import math

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

partition = cluster_config['cpu-partition']
account = cluster_config['cpu-account']

options += [f'--ntasks=1']

if "resources" in job_properties:
    resources = job_properties["resources"]

    if 'gpu' in resources and int(resources['gpu']) >= 1:
        num_gpu = str(resources['gpu'])
        account = cluster_config['gpu-account']

        if int(num_gpu) < 8:
            options += [f'--gpus={num_gpu}']
            options += [f'--nodes=1']
            partition = cluster_config['single-gpu-partition'] 
        else:
            #8 GPUS per node, each node has to be completely used on standard-g
            num_node = math.ceil(int(num_gpu)/8)
            options += [f'--nodes={num_node}']
            options += [f'--gpus-per-node=8']
            #options += [f'--cpu-bind=map_cpu:48,56,16,24,1,8,32,40']


            partition = cluster_config['multi-gpu-partition']
        rocm_dir = os.getenv("ROCM_PATH")
        options += ['--export', f'ALL,SINGULARITY_BIND="{rocm_dir}"']

    # we don't need explicit memory limiting for now
    if 'mem_mb' in resources:
        memory = str(resources['mem_mb']) 
        options += [f'--mem={memory}']


options += ['-p', partition]
options += ['-A', account]
#options += ['--nodes=1']
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
