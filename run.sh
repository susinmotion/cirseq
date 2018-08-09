#!/bin/bash

#$ -l h_rt=336:0:0
#$ -cwd
#$ -l arch=linux-x64
#$ -S /bin/bash
#$ -N cirseq

set -e

WORKDIR=$1
REFFILE=$2
SCRIPTDIR=$3
QUALITY=$4
FASTQS="${@:5}"

#clean up
mkdir -p ${WORKDIR}/index

# clean up reference file path, just get the filename
REFNAME=`echo $REFFILE | sed -e 's/.*\///g' | awk -F '.' '{print $1}'`
REFIDX=${WORKDIR}/index/${REFNAME}

# build bowtie index
bowtie2-build ${REFFILE} ${REFIDX}

# generate consensus
python ${SCRIPTDIR}/ConsensusGeneration.py $WORKDIR $FASTQS

# align consensus
bowtie2 -q --phred33 --no-hd --no-sq --local -x ${REFIDX} -U ${WORKDIR}/1_consensus.fastq.gz | gzip -c > ${WORKDIR}/2_alignment.sam.gz

# preprocess 1
python ${SCRIPTDIR}/preprocessing_1.py ${WORKDIR}

# align again
bowtie2 -q --phred33 --no-unal --no-hd --no-sq --local -x ${REFIDX} -U ${WORKDIR}/4_rearranged.fastq.gz | gzip -c > ${WORKDIR}/6_alignment.sam.gz

# preprocess 2
python ${SCRIPTDIR}/preprocessing_2.py ${WORKDIR} 

bowtie2 -q --phred33 --no-unal --no-hd --no-sq --local -x ${REFIDX} -U ${WORKDIR}/5_rotated.fastq.gz | gzip -c > ${WORKDIR}/9_alignment.sam.gz

bowtie2 -q --phred33 --no-unal --no-hd --no-sq --local -x ${REFIDX} -U ${WORKDIR}/8_rotated.fastq.gz | gzip -c > ${WORKDIR}/10_alignment.sam.gz

# preprocess 3
python ${SCRIPTDIR}/preprocessing_3.py ${WORKDIR} 

# combine results
cat ${WORKDIR}/3_alignment.sam.gz ${WORKDIR}/7_alignment.sam.gz ${WORKDIR}/11_alignment.sam.gz > ${WORKDIR}/data.sam.gz

# cleanup intermediate files
rm -f ${WORKDIR}/3_alignment.sam.gz ${WORKDIR}/7_alignment.sam.gz ${WORKDIR}/11_alignment.sam.gz ${WORKDIR}/2_alignment.sam.gz ${WORKDIR}/4_rearranged.sam.gz ${WORKDIR}/5_rotated.fastq.gz ${WORKDIR}/6_alignment.sam.gz ${WORKDIR}/8_rotated.fastq.gz ${WORKDIR}/9_alignment.sam.gz ${WORKDIR}/10_alignment.sam.gz

python ${SCRIPTDIR}/QualityFilter.py ${WORKDIR} ${REFFILE} ${QUALITY}

set +e
which R > /dev/null 2>&1
if [ $? -eq 0 ]; then
	echo "R detected, producing plots"
	Rscript ${SCRIPTDIR}/ParameterPlots.R ${WORKDIR}
else
	echo "R not detected, skipping plots"
fi
