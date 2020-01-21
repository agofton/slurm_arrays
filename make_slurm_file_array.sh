#!/bin/bash

### Set help and usage messages ###

HELP_MESSAGE="Given an input folder containing multiple input files this script will write a slurm file array that can be included in a sbatch launch script."

USAGE="Usage: {}=required []=optional ./$(basename "$0") {-a array_name} {-o output_file} {-s current file suffix eg. .fasta} [-d desired file suffix in input eg. .blast]"

### Default parameters ###
desired_suffix=$current_suffix

### Command line arguments ###
while getopts ha:i:o:s:d: OPTION
do
	case "${OPTION}" in
		h) echo "${HELP_MESSAGE}"
		   echo ""
		   echo "${USAGE}"
		   exit;;
	 	a) array_name=$OPTARG;;
		i) input_dir=$OPTARG;;
		o) output_file=$OPTARG;;
		s) current_suffix=$OPTARG;;
		d) desired_suffix=$OPTARG;;
		:) printf "missing argument for  -%s\n" "$OPTARG" >&2
		   echo "$usage" >&2
	  	   exit 1;;
	   	\?) printf "illegal option: -%s\n" "$OPTARG" >&2
		   echo "$usage" >&2
		   exit 1;;
	esac
done
shift $((OPTIND - 1))


file_array="(`for x in ${input_dir}/*${current_suffix}; do
				echo -n '"'
				echo -n $(basename "$x" ${current_suffix})${desired_suffix}
				echo -n '"'
			done`);"
file_array=`sed -E 's@""@" \\\\\\n"@g' <<< $file_array`


echo "${array_name}=${file_array}" > ${output_file} 

echo "${array_name} saved".
