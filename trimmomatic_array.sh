#!/bin/bash

####
# Written by Alexander Gofton, ANIC, CSIRO, 2019
# alexander.gofton@csiro.au; alexander.gofton@gmail.com
####

### Help and usage info ###
HELP_MESSAGE="Writes and launches slurm array script sending each sample in -i {input dir} to its own node to run trimmomatic.
Assumes seqs are paired-end with fwd and rev seqs in two .fastq files (R1 & R2) (Illumina format .fastq).
Changes trimmomatic QC params by editing line 148. By default it is set up to trim NEB adapter sequences, perform a sliding window analysis, and remove short reads."

USAGE="Usage: $(basename "$0")
{-i /input/dir/containing/R1&R2.fastq}
{-o /all/output/will/go/here}
{-a Trimmomatic_adapter_file.fasta}
{-j JOB_NAME}
{-t max time (hh:mm:ss format)}
{-n nsamples}
{-c run njobs at on}
[-h print this help message]"

### Set defaults ###
JOB_NAME=trimmomatic
MAX_TIME=02:00:00
MEM=50GB
THREADS=20

### Command line arguments ###
while getopts hi:o:a:j:t:m:p: option
do
	case "${option}"
	in
		h) echo "$HELP_MESSAGE"
		    echo ""
		    echo "$USAGE"
			exit;;
		i) INPUT_DIR=${OPTARG};;
		o) OUTPUT_DIR=${OPTARG};;
		a) ADAP_FILE=${OPTARG};;
		j) JOB_NAME=${OPTARG};;
		t) MAX_TIME=${OPTARG};;
		m) MEM=${OPTARG};;
		p) THREADS=${OPTARG};;
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

#Create input and output arrays
############################################
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

OUT_INDEX="(`for x in ${INPUT_DIR}/*R1.fastq
do
	echo -n '"'
	echo -n $(basename "$x" _R1.fastq).fastq
	echo -n '"'
done`);"
OUT_INDEX=`sed -E 's@""@" \\\\\\n"@g' <<< ${OUT_INDEX}`

TRIMLOG_INDEX="(`for x in ${INPUT_DIR}/*R1.fastq
do
	echo -n '"'
	echo -n $(basename "$x" _R1.fastq).trimlog
	echo -n '"'
done`);"
TRIMLOG_INDEX=`sed -E 's@""@" \\\\\\n"@g' <<< ${TRIMLOG_INDEX}`

SUMMARY_INDEX="(`for x in ${INPUT_DIR}/*R1.fastq
do
	echo -n '"'
	echo -n $(basename "$x" _R1.fastq).trimsummary
	echo -n '"'
done`);"
SUMMARY_INDEX=`sed -E 's@""@" \\\\\\n"@g' <<< ${SUMMARY_INDEX}`

### Script variables ###
SLURM_SCRIPT="${OUTPUT_DIR}/slurm_logs/${JOB_NAME}_`date -I`.sh"
NARRAYS=$(('ls -1 ${INPUT_DIR}/*.fasta | wc -l'-1))

R1='${R1_INDEX[$i]}'
R2='${R2_INDEX[$i]}'
OUT='${OUT_INDEX[$i]}'
SUMMARY='${SUMMARY_INDEX[$i]}'
TRIMLOG='${TRIMLOG_INDEX[$i]}'

SATID1='"$SLURM_ARRAY_TASK_ID"'
SATID2='${SLURM_ARRAY_TASK_ID}'

### Write slurm array script ###
echo """#!/bin/bash
#SBATCH --job-name=${JOB_NAME}
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=${THREADS}
#SBATCH --time ${MAX_TIME}
#SBATCH -o ${OUTPUT_DIR}/slurm_logs/${JOB_NAME}_`date -I`_%A_%a.out
#SBATCH --array=0-${NARRAYS}

module load trimmomatic/0.38

R1_INDEX=${R1_INDEX}
R2_INDEX=${R2_INDEX}
OUT_INDEX=${OUT_INDEX}
TRIMLOG_INDEX=${TRIMLOG_INDEX}
SUMMARY_INDEX=${SUNNARY_INDEX}


if [ ! -z ${SATID1} ]
then
i=${SATID2}

trimmomatic PE \
-threads ${THREADS} \
-trimlog ${OUTPUT_DIR}/${TRIMLOG} \
-summary ${OUTPUT_DIR}/${SUMMARY} \
${INPUT_DIR}/${R1} ${INPUT_DIR}/${R2} \
-baseout ${OUTPUT_DIR}/${OUT} \
ILLUMINACLIP:${ADAP_FILE}:2:30:10 \
SLIDINGWINDOW:10:20 \
MINLEN:50

else
	echo Error: missing array index as SLURM_ARRAY_TASK_ID

fi

""" > ${SLURM_SCRIPT}

### Launch slurm array ###
sbatch ${SLURM_SCRIPT}
