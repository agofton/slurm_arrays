#!/bin/bash
#####
# Written by Alexander W. Gofton, ANIC, CSIRO, 2019
# alexander.gofton@csiro.au; alexander.gofton@gmail.com
####

### Set help and usage messages ###
HELP_MESSAGE="Given a folder of paired .fastq files as input, this script will create a slurm array, sending each pair of files to
its own node to map reads to an indexed reference genome/transcriptom using bowtie2. Assumes file names end in _R1.fastq or _R2.fastq."

USAGE="Usage: $(basename "$0")
{-d path/to/indexed/genome(s)/index_prefix}
{-i /input/dir}
{-o /output/dir}
{-j job_name}
{-t max time (hh:mm:ss format)}
{-p nthreads}
{-m mem in GB eg. 128GB}
[-h show this help message]"

### Set default parameters ###
JOB_NAME=bowtie2
MAX_TIME=02:00:00
THREADS=20
MEM=128GB

### Command line arguments ###
while getopts hd:i:o:j:t:p:m: option; do
	case "${option}" in
		h) echo "$hmessage"
		   echo "$usage"
		   exit;;
		d) DB=$OPTARG;;
		i) INPUT_DIR=$OPTARG;;
		o) OUTPUT_DIR=$OPTARG;;
		j) JOB_NAME=$OPTARG;;
		t) MAX_TIME=$OPTARG;;
		p) THREADS=$OPTARG;;
		m) MEM=$OPTARG;;
		:) printf "missing argument for  -%s\n" "$OPTARG" >&2
		   echo "$usage" >&2
	  	   exit 1;;
	   \?) printf "illegal option: -%s\n" "$OPTARG" >&2
		   echo "$usage" >&2
		   exit 1;;
	esac
done
shift $((OPTIND - 1))

### Create output directories ###
mkdir -p ${OUTPUT_DIR}/slurm_logs

### Create input and output arrays ###
R1_INDEX="(`for x in ${INPUT_DIR}/*R1.fastq
do
	echo -n '"'
	echo -n $(basename "$x")
	echo -n '"'
done`);"
R1_INDEX=`sed -E 's@""@" \\\\\\n"@g' <<< ${R1_INDEX}`

R2_INDEX="(`for x in ${INPUT_DIR}/*R2.fastq
do
	echo -n '"'
	echo -n $(basename "$x")
	echo -n '"'
done`);"
R2_INDEX=`sed -E 's@""@" \\\\\\n"@g' <<< ${R2_INDEX}`

NOT_MAPPED_INDEX="(`for x in ${INPUT_DIR}/*R1.fastq
do
	echo -n '"'
	echo -n $(basename "$x" _R1.fasta)_R%_not_mapped.fastq
	echo -n '"'
done`);"
NOT_MAPPED_INDEX=`sed -E 's@""@" \\\\\\n"@g' <<< ${NOT_MAPPED_INDEX}`

MAPPED_INDEX="(`for x in ${INPUT_DIR}/*R1.fastq
do
	echo -n '"'
	echo -n $(basename "$x" _R1.fasta)_R%_mapped.fastq
	echo -n '"'
done`);"
MAPPED_INDEX=`sed -E 's@""@" \\\\\\n"@g' <<< ${MAPPED_INDEX}`

SAM_INDEX="(`for x in ${INPUT_DIR}/*R1.fastq
do
	echo -n '"'
	echo -n $(basename "$x" _R1.fasta).sam
	echo -n '"'
done`);"
SAM_INDEX=`sed -E 's@""@" \\\\\\n"@g' <<< ${SAM_INDEX}`

### Set SLURM script variables ###
SATID1='"$SLURM_ARRAY_TASK_ID"'
SATID2='${SLURM_ARRAY_TASK_ID}'

SLURM_SCRIPT="${OUTPUT_DIR}/slurm_logs/${JOB_NAME}_`date -I`.slurm.script"
NARRAYS=$(('ls -1 ${INPUT_DIR}/*.fasta | wc -l'-1))

R1='${R1_INDEX[$i]}'
R2='${R2_INDEX[$i]}'
NOT_MAPPED='${NOT_MAPPED_INDEX[$i]}'
MAPPED='${MAPPED_INDEX[$i]}'
SAM='${SAM_INDEX[$i]}'

### Write SLURM array script ###
echo """#!/bin/bash

#SBATCH --job-name=${JOB_NAME}
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=${THREADS}
#SBATCH --time ${MAX_TIME}
#SBATCH -o ${OUTPUT_DIR}/logs/${JOB_NAME}_%A_sample_%a.out
#SBATCH -e ${OUTPUT_DIR}/logs/${JOB_NAME}_%A_sample_%a.err
#SBATCH --array=0-${NARRAYS}
#SBATCH --mem=${MEM}

module load bowtie/2.2.9

R1_INDEX=${R1_INDEX}
R2_INDEX=${R2_INDEX}
NOT_MAPPED_INDEX=${NOT_MAPPED_INDEX}
MAPPED_INDEX=${MAPPED_INDEX}
SAM_INDEX=${SAM_INDEX}

if [ ! -z ${SATID1} ]
then
i=${SATID2}

bowtie2 \
-q \
-x ${DB} \
-1 ${INPUT_DIR}/${R1} \
-2 ${INPUT_DIR}/${R2} \
--threads ${THREADS} \
--sensitive-local \
--un-conc ${OUTPUT_DIR}/${NOT_MAPPED} \
--al-conc ${OUTPUT_DIR}/${MAPPED} \
-S ${OUTPUT_DIR}/${SAM}

else
	echo "Error: missing array index as SLURM_ARRAY_TASK_ID"
fi
""" > ${SLURM_SCRIPT}

# pushing script to slurm
sbatch ${SLURM_SCRIPT}
