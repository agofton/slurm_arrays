#!/bin/bash

####
# Written by Alexander W. Gofton, CSIRO, 2019
# alexander.gofton@gmail.com, alexander.gofton@csiro.au
####

### Set help and usage messages ###
HELP_MESSAGE="This script takes a directory containing fasta files and creates a SLURM array sending each file to its own node to pefrorm diamond blastx to the nr database using 'sensitive' settings. Results will be placed in {-o /output/dir} in tabular format (6 - for easy parsing)."

USAGE="Usage: $(basename "$0")
{-d path/to/nr/.dmnd <- defaul for bioref is /data/bioref/diamond_db/nr-xxxxxx_diamondVxxxx.dmnd}}
{-i /input/dir}
{-o /output/dir}
{-e minimum evalue (real value eg. 0.0000000001)}
{-j job_name}
{-t max time (hh:mm:ss format), default 12:00:00}
{-m max RAM in GB, default=128GB}
[-h show this help message]"

### Default parameters ###
MEM="128GB"
MAX_TIME="12:00:00"
JOB_NAME="diamond_array"
THREADS="20"
EVAL=0.0000000001

### Command line arguments ###
while getopts hd:i:o:e:j:t:m: option; do
	case "${option}" in
		h) echo "$HELP_MESSAGE"
		   echo ""
		   echo "$USAGE"
		   exit;;
		d) DB=$OPTARG;;
		i) INPUT_DIR=$OPTARG;;
		o) OUTPUT_DIR=$OPTARG;;
		e) EVAL=$OPTARG;;
		j) JOB_NAME=$OPTARG;;
		t) MAX_TIME=$OPTARG;;
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

### Create directories ###
mkdir -p ${OUTPUT_DIR}/slurm_logs

### Create input and output arrays ###
INPUT_INDEX="(`for x in ${INPUT_DIR}/*.fasta
do
	echo -n '"'
	echo -n $(basename "$x")
	echo -n '"'
done`);"
INPUT_INDEX=`sed -E 's@""@" \\\\\\n"@g' <<< ${INPUT_INDEX}`

# Output array
OUTPUT_INDEX="(`for x in ${INPUT_DIR}/*.fasta
do
	echo -n '"'
	echo -n $(basename "$x" .fasta).diamond.out
	echo -n '"'
done`);"
OUTPUT_INDEX=`sed -E 's@""@" \\\\\\n"@g' <<< ${OUTPUT_INDEX}`

### SLURM script variables ###
SATID1='"$SLURM_ARRAY_TASK_ID"'
SATID2='${SLURM_ARRAY_TASK_ID}'

SLURM_SCRIPT="${OUTPUT_DIR}/slurm_logs/${JOB_NAME}_`date -I`.slurm.script"
NARRAYS=$(('ls -1 ${INPUT_DIR}/*.fasta | wc -l'-1))

INPUT='${INPUT_INDEX[$i]}'
OUTPUT='${INPUT_INDEX[$i]}'

### Write slurm sript ###
echo """#!/bin/bash

#SBATCH --job-name ${JOB_NAME}
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=20
#SBATCH --time ${MAX_TIME}
#SBATCH --output ${OUTPUT_DIR}/slurm_logs/${JOB_NAME}_%A_sample_%a.out
#SBATCH --array=0-${NARRAYS}
#SBATCH --mem=${MEM}

module load diamond/0.9.22 bioref blast+

INPUT_INDEX=${INPUT_INDEX}
OUTPUT_INDEX=${INPUT_INDEX}

if [ ! -z ${SATID1} ]
then
i=${SATID2}

diamond blastx \
--db ${DB} \
--query ${INPUT_DIR}/${INPUT} \
--out ${OUTPUT_DIR}/${OUTPUT} \
--threads ${THREADS} \
--strand both --sensitive \
--evalue ${EVAL} \
--top 5 --id 40 \
--outfmt 6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore qlen stitle staxids salltitles

else
	echo "Error: missing array index as SLURM_ARRAY_TASK_ID"
fi
""" > ${SLURM_SCRIPT}

### Launch jobb ###
sbatch ${SLURM_SCRIPT}
