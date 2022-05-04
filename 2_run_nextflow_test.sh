#!/bin/bash

## run screen
# open a screen by typing 'screen' and hitting 'Enter'

## Purge 
module --quiet purge  # Reset the modules to the system default



## NB NOTE!!
## before running this, on the login node go to $USERWORK and run the following two lines (change the path to the .nf file to the full path to your copy)
# module load Nextflow/21.03.0
# nextflow run /cluster/home/sethmusker/bergen_workshop/hybpiper-rbgv-pipeline-bergen.nf --help
## This will download the requirements for the pipeline. This won't happen within the script because it doesn't have internet access. I think.

## you may also have to manually download the nextflow jar file like so
# mkdir $HOME/.nextflow/framework/21.03.0-edge
# cd $HOME/.nextflow/framework/21.03.0-edge
# wget https://www.nextflow.io/releases/v21.03.0-edge/nextflow-21.03.0-edge-one.jar

## Load modules
module load Nextflow/21.03.0


## Run script

cd $USERWORK

nextflow run /cluster/home/sethmusker/bergen_workshop/hybpiper-rbgv-pipeline-bergen.nf \
    -c /cluster/home/sethmusker/bergen_workshop/my-hybpiper-rbgv-bergen-8core.config \
    --illumina_reads_directory /cluster/home/sethmusker/bergen_workshop/test_reads/ \
    --target_file /cluster/home/sethmusker/bergen_workshop/Targets_ERICA_all_together_bergen_subset.fasta \
    --cov_cutoff 2 \
    -profile slurm \
    --run_intronerate \
    --num_forks 2 \
    --cleanup \
    --outdir /cluster/work/users/sethmusker/results_test

## close the screen by pressing 'ctrl+A' then 'D'
## you can re-attach to the screen to check on the job or cancel it (press 'ctrl+C') by typing 'screen -r' and hitting 'Enter'

if [[ -d $USERWORK/results_test ]]; then
	cp $USERWORK/results_test /cluster/home/sethmusker/bergen_workshop
fi
