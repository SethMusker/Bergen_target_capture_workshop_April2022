#!/bin/bash
#SBATCH --account=nn8091k
#SBATCH --job-name=vethybpiper_parallel
#SBATCH --time=00-02:00:00
#SBATCH --mem-per-cpu=3G
#SBATCH --ntasks=1 --cpus-per-task=8 --ntasks-per-node=1

#module --quiet purge  # Reset the modules to the system default


TV=$HOME/TargetVet
cd $TV
for i in *.R;do
 check=`grep 'Rlibs' ${i} | wc -l`
 if [[ ${check} -eq 0 ]]; then
  cp $i $i.temp
  printf ".libPaths('~/Rlibs')\n" | cat - $i.temp > $i
  rm $i.temp
 fi
done


cd /cluster/work/users/sethmusker/malinae_353

export LMOD_DISABLE_SAME_NAME_AUTOSWAP=no

module load R/4.1.2-foss-2021b
module load BLAST+/2.12.0-gompi-2021b
module load parallel/20190922-GCCcore-8.3.0

TARGET=/cluster/work/users/sethmusker/malinae_353/kew_probes_Malus_exons_concat.fasta
NAMELIST=/cluster/work/users/sethmusker/malinae_353/hybpiper_rgbv_results/01_namelist/namelist.txt
GENELIST=/cluster/work/users/sethmusker/malinae_353/genelist.txt
HYBDIR=/cluster/work/users/sethmusker/malinae_353/hybpiper_rgbv_results/04_processed_gene_directories

echo "running in parallel with $SLURM_CPUS_PER_TASK cores"
bash $TV/VetHybPiper.sh -V $TV -D $HYBDIR \
    -T $TARGET -S $NAMELIST -G $GENELIST \
    -L 50 -I FALSE -C TRUE -d FALSE \
    -O blastn_length50_parallel -M FALSE -F TRUE \
    -X TRUE -t $SLURM_CPUS_PER_TASK

#module load BBMap/38.79-GCC-8.3.0

#bash $TV/VetHybPiper.sh -V $TV -D $HYBDIR \
#    -T $TARGET -S $NAMELIST -G $GENELIST \
#    -L 50 -I FALSE -C TRUE -d TRUE \
#    -O blastn_length50_parallel -M FALSE -F TRUE \
#    -X TRUE -t $SLURM_CPUS_PER_TASK


