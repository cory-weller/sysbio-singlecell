#!/bin/bash

#SBATCH --cpus-per-task 1
#SBATCH --mem-per-cpu=32G
#SBATCH --time 96:00:00

module purge
module load snakemake/9

# block required for conda setup, prior to conda commands working
__conda_setup="$('/data/$USER/conda/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/data/$USER/conda/etc/profile.d/conda.sh" ]; then
        . "/data/$USER/conda/etc/profile.d/conda.sh"
    else
        export PATH="/data/$USER/conda/bin:$PATH"
    fi
fi
unset __conda_setup

# Pull profile, this will only run once, and is required for running on Biowulf
if [ ! -d 'snakemake_profile' ]; then
    git clone -b snakemake9 https://github.com/NIH-HPC/snakemake_profile.git
fi

# Bind external directories on Biowulf: 
# code from /usr/local/current/singularity/app_conf/sing_binds
# spawn a subshell to protect the environment
export SINGULARITY_BINDPATH="$(
    unset gpfs_links link gpfs_dirs add_comma
    gpfs_links="$(/usr/bin/ls -d /gs*)"

    # check to see if any gs* links are broken
    for link in $gpfs_links; do 
        if [ -e "${link}" ]; then
            gpfs_dirs+="${add_comma:-}${link}"
            # only prepend the comma _after_ the first iteration 
            add_comma=,
        fi
    done
    bindpath="${gpfs_dirs:-},/vf,/spin1,/data,/fdb,/gpfs"
    [ -d /lscratch ] && export bindpath="${bindpath},/lscratch"
    echo $bindpath
)"
export APPTAINER_BINDPATH=$SINGULARITY_BINDPATH

# RUN SCRIPT
snakemake --cores 1 --use-conda  --use-envmodules --profile snakemake_profile 