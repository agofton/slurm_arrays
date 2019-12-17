#!/bin/bash

####
# Written by Alexander W. Gofton, CSIRO, 2019
# alexander.gofton@gmail.com, alexander.gofton@csiro.au
####

### Set help and usage messages ###

HELP_MESSAGE="This script takes a directort containing fasta files and creates a SLURM array sending each file to its own node to perform blast to the nt database. Results will be places in (-o /output/dir} in tabular format 6 for easy parsing)"

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

MEM="50GB"
MAX_TIME="24:00:00"
JOB_NAME="blastn"
THREADS="20"
MAX_HITS="100"
MAX_HSPS="5"
EVAL="0.0000000001"

### Command line arguments ###

while getopts hi:o:j:t:m:z:a:p:e: OPTION
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
		z) THREADS=$OPTARG;;
		a) MAX_HITS=$OPTARG;;
		p) MAX_HSPS=$OPTARG;;
		e) EVAL=$OPTARG;;
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

INPUT_INDEX="(`for x in ${INPUT_DIR}/*.fasta; do
					echo -n '"'
					echo -n $(basename "$x")
					echo -n '"'
				done`);"
	INPUT_INDEX=`sed -E 's@""@" \\\\\\n"@g' <<< ${INPUT_INDEX}`
#blast out index
OUTPUT_INDEX="(`for x in ${INPUT_DIR}/*.fasta; do
					echo -n '"'
					echo -n $(basename "$x" .fasta).blast
					echo -n '"'
				done`);"
	OUTPUT_INDEX=`sed -E 's@""@" \\\\\\n"@g' <<< ${OUTPUT_INDEX}`

### SLURM SCRIPT VARIABLES ###

SATID1='"$SLURM_ARRAY_TASK_ID"'
SATID2='${SLURM_ARRAY_TASK_ID}'

INPUT='${INPUT_INDEX[$i]}'
OUTPUT='${OUTPUT_INDEX[$i]}'

SLURM_SCIPT="${OUPUT_DIR}/slurm_logs/${job_name}_`date -I`.sh"
NARRAYS=$((`ls -1 ${INPUT_DIR}/*.fasta | wc -l`-1))

### Write slurm script ###

echo """#!/bin/bash

#SBATCH --job-name ${JOB_NAME}
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=20
#SBATCH --time=${MAX_TIME}
#SBATCH --output ${OUTPUT_DIR}/logs/${JOB_NAME}_%A_%a.out
#SBATCH --mem=${MEM}
#SBATCH --array=0-${NARRAYS}

module load blast+
module load bioref

INPUT_INDEX=${INPUT_INDEX}
OUTPUT_INDEX=${OUTPUT_INDEX}

if [ ! -z ${SATID1} ]
then
i=${SATID2}

blastn -task megablast \
-query ${INPUT_DIR}/${INPUT} \
-db /data/bioref/blast/ncbi/nt \
-out ${OUTPUT_DIR}/${OUTPUT} \
-strand both \
-num_threads 20 \
-outfmt '6 qseqid saccver pident length mismatch gapopen qstart qend sstart send ssciname staxid'
-max_target_seqs ${MAX_HITS} \
-max_hsps ${MAX_HSPS} \
-evalue ${EVAL}


else
	echo "Error: missing array index as SLURM_ARRAY_TASK_ID"
fi

" > ${slurm_script}

# push job to slurm
sbatch ${slurm_script}
