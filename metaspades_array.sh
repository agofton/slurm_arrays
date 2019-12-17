#!/bin/bash

####
# Written by Alexander Gofton, ANIC, CSIRO, 2018
# alexander.gofton@gmail.com; alexander.gofton@csiro.au
####

# set args & help
hmessage="This sript will launch a slurm array sending each sample (consisting of a R1, R2, and R0 .fasta or fastq file)
to its own node for denovo assembly with metasapdes"
usage="Usage: $(basename "$0")
{-i /input/dir/}
{-o /all/output/goes/here}
{-m metaspades tmp directory}
{-j job_name}
{-t max time hh:mm:ss}
{-n n_samples}
{-c run n jobs at once}
{-t threads}
{-k kmers - comma separated list 21,35,71,95,125}
{-m memmory (in GB)}
[-h show with help message]"

while getopts hi:o:m:j:t:n:c:m:t:k: option
do
	case "${option}"
	in
		h) echo "$hmessage"
		   echo "$usage"
		   exit;;
		i) in_dir=$OPTARG;;
		o) out_dir=$OPTARG;;
		m) tmp_dir=$OPTARG;;
		j) job_name=$OPTARG;;
		t) max_time=$OPTARG;;
		m) mem=$OPTARG;;
		t) threads=$OPTARG;;
		k) kmers=$OPTARG;;
		n) njobs=$OPTARG;;
		c) njobs_at_once=$OPTARG;;
		:) printf "missing argument for  -%s\n" "$OPTARG" >&2
		   echo "$usage" >&2
	  	   exit 1;;
	   \?) printf "illegal option: -%s\n" "$OPTARG" >&2
		   echo "$usage" >&2
		   exit 1;;
	esac
done
shift $((OPTIND - 1))
##########################################################
# make dirs
mkdir -p ${out_dir}
mkdir -p ${out_dir}/logs
mkdir -p ${tmp_dir}
###########################################################
# set vars
slurm_script=${out_dir}/logs/metaspades_array_${job_name}_`date -I`.q
narrays=$(($njobs-1))
#########################################################################
# R1 index
R1_index="(`for x in ${in_dir}/*R1*; do
				echo -n '"'
				echo -n $(basename $x)
				echo -n '"'
			done`);"
	R1_index=`sed -E 's@""@" \\\\\\n"@g' <<< ${R1_index}`
# R2 index
R2_index="(`for x in ${in_dir}/*R2*; do
				echo -n '"'
				echo -n $(basename $x)
				echo -n '"'
			done`);"
	R2_index=`sed -E 's@""@" \\\\\\n"@g' <<< ${R2_index}`
#out index
out_index="(`for x in ${in_dir}/*R1*; do
				y=$(basename $x)
				y=${y:0:4}_metaspades_out
				echo -n '"'
				echo -n ${y}
				echo -n '"'
			done`);"
	out_index=`sed -E 's@""@" \\\\\\n"@g' <<< ${out_index}`
##############################################################
# script vars
satid1='"$SLURM_ARRAY_TASK_ID"'
satid2='${SLURM_ARRAY_TASK_ID}'

R1='${R1_INDEX[$i]}'
R2='${R2_INDEX[$i]}'
out='${OUT_INDEX[$i]}'
##############################################################
# write scrip
echo "#!/bin/bash

#SBATCH -J ${job_name}
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=${threads}
#SBATCH --time=${max_time}
#SBATCH -o ${out_dir}/logs/${job_name}_%A_sample_%a.out
#SBATCH -e ${out_dir}/logs/${job_name}_%A_sample_%a.err
#SBATCH --mem=${mem}GB
#SBATCH --array=0-${narrays}%${njobs_at_once}

module load spades/3.12.0

export OMP_NUM_THREADS=${threads}

R1_INDEX=${R1_index}
R2_INDEX=${R2_index}
OUT_INDEX=${out_index}

if [ ! -z ${satid1} ]
then
i=${satid2}

spades.py --meta --only-assembler -t 20 -m ${mem} -1 ${in_dir}/${R1} -2 ${in_dir}/${R2} -o ${out_dir}/${out} --tmp-dir ${tmp_dir}/${out} -k ${kmers}

else
	echo "Error: missing array index as SLURM_ARRAY_TASK_ID"
fi
" > ${slurm_script}

# push job to slurm
sbatch ${slurm_script}
