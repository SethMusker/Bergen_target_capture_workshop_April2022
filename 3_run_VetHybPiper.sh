#!/bin/bash
#SBATCH --account=nn8091k
#SBATCH --job-name=test
#SBATCH --time=00-02:00:00
#SBATCH --mem-per-cpu=3G
#SBATCH --ntasks=1 --cpus-per-task=1 --ntasks-per-node=1

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

module load R/4.1.2-foss-2021b
module load BLAST+/2.12.0-gompi-2021b

TARGET=/cluster/work/users/sethmusker/malinae_353/kew_probes_Malus_exons_concat.fasta
NAMELIST=/cluster/work/users/sethmusker/malinae_353/hybpiper_rgbv_results/01_namelist/namelist.txt
GENELIST=/cluster/work/users/sethmusker/malinae_353/genelist.txt
HYBDIR=/cluster/work/users/sethmusker/malinae_353/hybpiper_rgbv_results/04_processed_gene_directories

HAS_CRLF=$(file $GENELIST |grep CRLF |wc -l)
if [[ ${HAS_CRLF} -eq 1 ]]; then
    sed 's/\r$//' $GENELIST > $HYBDIR/`basename $GENELIST`
else
    cp $GENELIST $HYBDIR
fi

HAS_CRLF=$(file $NAMELIST |grep CRLF |wc -l)
if [[ ${HAS_CRLF} -eq 1 ]]; then
    sed 's/\r$//' $NAMELIST > $HYBDIR/`basename $NAMELIST`
else
    cp $NAMELIST $HYBDIR
fi

cp $TARGET $HYBDIR

TARGET=`basename $TARGET`
NAMELIST=`basename $NAMELIST`
GENELIST=`basename $GENELIST`

bash $TV/VetHybPiper.sh -V $TV -D $HYBDIR \
    -T $TARGET -S $NAMELIST -G $GENELIST \
    -L 50 -I FALSE -C TRUE -d FALSE \
    -O blastn_length50 -M FALSE -F TRUE 
