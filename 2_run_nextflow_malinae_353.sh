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

cd $USERWORK/malinae_353

## we configure READS_FIRST to use 20 cores as we have only 20 genes (hybpiper parallelises spades assembly across genes)
## we specify 26 forks as we have 26 samples
nextflow run /cluster/home/sethmusker/bergen_workshop/hybpiper-rbgv-pipeline-bergen.nf \
    -c /cluster/home/sethmusker/bergen_workshop/my-hybpiper-rbgv-bergen-20core.config \
    --illumina_reads_directory /cluster/work/users/sethmusker/malinae_353/ANG353/ \
    --target_file /cluster/work/users/sethmusker/malinae_353/kew_probes_Malus_exons_concat.fasta \
    --cov_cutoff 2 \
    -profile slurm \
    --run_intronerate \
    --num_forks 26 \
    --cleanup \
    --outdir /cluster/work/users/sethmusker/malinae_353/hybpiper_rgbv_results

## close the screen by pressing 'ctrl+A' then 'D'
## you can re-attach to the screen to check on the job or cancel it (press 'ctrl+C') by typing 'screen -r' and hitting 'Enter'

cd /cluster/projects/nn8091k/10deduplicated_reads
mkdir -p renamed_seth
ls | cut -d'.' -f1 > names.txt
while read NAME;do
    cp ${NAME}.R1.fastq renamed_seth/${NAME}_R1.fastq
    cp ${NAME}.R2.fastq renamed_seth/${NAME}_R2.fastq
done < names.txt


nextflow run /cluster/home/sethmusker/bergen_workshop/hybpiper-rbgv-pipeline-bergen.nf \
    -c /cluster/home/sethmusker/bergen_workshop/my-hybpiper-rbgv-bergen-20core-shortJobs.config \
    --illumina_reads_directory /cluster/projects/nn8091k/10deduplicated_reads/renamed_seth \
    --target_file /cluster/work/users/sethmusker/malinae_353/kew_probes_Malus_exons_concat.fasta \
    --cov_cutoff 2 \
    -profile slurm \
    --num_forks 26 \
    --cleanup \
    --outdir /cluster/work/users/sethmusker/malinae_353/hybpiper_rgbv_results_deduped

# Run using Martha's ParalogWizard-derived new target file
nextflow run /cluster/home/sethmusker/bergen_workshop/hybpiper-rbgv-pipeline-bergen.nf \
    -c /cluster/home/sethmusker/bergen_workshop/my-hybpiper-rbgv-bergen-20core-shortJobs.config \
    --illumina_reads_directory /cluster/projects/nn8091k/10deduplicated_reads/renamed_seth \
    --target_file /cluster/projects/nn8091k/customized_reference_div_7.0_15.93.for_HybPiper_concatenated_exons.fasta \
    --cov_cutoff 2 \
    -profile slurm \
    --num_forks 26 \
    --cleanup \
    --outdir /cluster/work/users/sethmusker/malinae_353/hybpiper_rgbv_results_PW_targets



if [[ -d $USERWORK/hybpiper_rgbv_results ]]; then
	cp $USERWORK/hybpiper_rgbv_results /cluster/home/sethmusker/bergen_workshop
fi
