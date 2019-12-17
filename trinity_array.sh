#!/bin/bash

 ####
# Written by Alexander W. Gofton, CSIRO, 2019
# alexander.gofton@gmail.com, alexander.gofton@csiro.au
####

### Set help and usage messages ###
HELP_MESSAGE="This script takes a folder containg paired R1 and R2 Illumina RNAseq reads and send each pair of files to its own node to perform Trinity de novo assembly"

USAGE="Usage: $(basename "$0")
{-i /path/to/input/fasta/files}
{-o /all/output/goes/here}
{-j job_name}
{-t max time (hh:mm:ss)}
{-m RAM to reques in GB eg. 80GB}
{-a num_alignments (int)}
{-d num_descriptions (int)}
{-p max_hsps (int)}
{-e evalue (real)}
[-h show this help message]"

### Default parameters ###
MEM="2990GB"
MAX_TIME="28:00:00"
JOB_NAME="trinity"
THREADS="48"

### Command line arguments ###
while getopts hi:o:j:t:m:p: OPTION
do
	case "${OPTION}" in
		h) echo "${HELP_MESSAGE}"
		   echo ""
		   echo "${USAGE}"
		   exit;;
	   	i) INPUT_DIR=$OPTARG;;
   		o) OUTPUT_DIR=$OPTARG;;
		j) JOB_NAME=$OPTARG;;
		t) MAX_TIME=$OPTARG;;
		m) MEM=$OPTARG;;
		p) THREADS=$OPTARG;;
		:) printf "missing argument for  -%s\n" "$OPTARG" >&2
		   echo "$usage" >&2
	  	   exit 1;;
	   \?) printf "illegal option: -%s\n" "$OPTARG" >&2
		   echo "$usage" >&2
		   exit 1;;
	esac
done
shift $((OPTIND - 1))

### Create directories ###
mkdir -p ${OUTPUT_DIR}/slurm_logs

### Create input and output arrays ###
R1_INDEX="(`for x in ${INPUT_DIR}/R1.fastq
do
	echo -n '"'
	echo -n $(basename "$x")
	echo -n '"'
done`);"
R1_INDEX=`sed -E 's@""@" \\\\\\n"@g' <<< ${R1_INDEX}`

R2_INDEX="(`for x in ${INPUT_DIR}/R2.fastq
do
	echo -n '"'
	echo -n $(basename "$x")
	echo -n '"'
done`);"
R2_INDEX=`sed -E 's@""@" \\\\\\n"@g' <<< ${R2_INDEX}`

OUTPUT_INDEX="(`for x in ${INPUT_DIR}/R1.fastq
do
	echo -n '"'
	echo -n $(basename "$x" _R1.fastq)
	echo -n '"'
done`);"
OUTPIUT_INDEX=`sed -E 's@""@" \\\\\\n"@g' <<< ${OUTPUT_INDEX}`

### SLURM SCRIPT VARIABLES ###
SATID1='"$SLURM_ARRAY_TASK_ID"'
SATID2='${SLURM_ARRAY_TASK_ID}'

R1='${R1_INDEX[$i]}'
R1='${R2_INDEX[$i]}'
OUTPUT='${OUTPUT_INDEX[$i]}'

SLURM_SCIPT="${OUPUT_DIR}/slurm_logs/${job_name}_`date -I`.sh"
NARRAYS=$((`ls -1 ${INPUT_DIR}/*.fasta | wc -l`-1))

### Write SLURM script ###
echo """#!/bin/bash

#SBATCH --job-name=${JOB_NAME}
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=${THREADS}
#SBATCH --cpus-per-task=1
#SBATCH --time=${MAX_TIME}
#SBATCH --output=${OUTPUT_DIR}/slurm_logs/${JOB_NAME}_%A_%a.out
#SBATCH --mem=${MEM}
#SBATCH --array=0-${NARRAYS}

module load trinity/2.8.4
module load salmon
module load bowtie

export OMP_NUM_THREADS=${THREADS}

R1_INDEX=${R1_INDEX}
R2_INDEX=${R2_INDEX}
OUTPUT_INDEX=${OUTPUT_INDEX}

if [ ! -z ${SATID1} ]
then
i=${SATID2}

export OUT_DIR=${OUTPUT_DIR}/${OUTPUT_ARRAY[$i]}
mkdir ${MEMDIR}/read_partitions
ln -s ${MEMDIR}/read_partitions ${OUT_DIR}

Trinity \
--seqType fq \
--max_memort ${MEM} \
--left ${R1} \
--right ${R2}\
--CPU ${THREADS} \
--min_contig_length 100 \
--output ${OUTPUT_DIR}/${OUTPUT} \
--ful_cleanup

else
	echo "Error with task array"
fi
"""

### Launch slurm array ###
sbatch #{SLURM_SCIPT}
