#!/bin/bash
#
#----------------------------------------------------------------------
# sort_series.sh
# If raw data files are all in the same directory, copy to a backup,
# and then move them to series directories.
#
# Revision 1.1
# 05.07.2013
#  Updated to work with the paths.sh file in the preproc dir.
#
# Version 1.0
# 10.05.2011
#
# Josh Tremel
# (tremeljosh@gmail.com)
# University of Pittsburgh
#----------------------------------------------------------------------

#----------------------------------------------------------------
# Program and User info
#----------------------------------------------------------------
COMMAND=$0
PROGRAM=sort_series.sh
VERSION=1.1
USER=$(whoami)

MINARGS=1

#----------------------------------------------------------------
# Program Usage
#----------------------------------------------------------------
usage() {
	cat << usageEOF
Usage: sort_series.sh <str input_directory>
Options: <none currently>
Description:
	NOTE: This is only if the raw data directory contains all the
	files to process (i.e., not separated into series directories).
	
	Copies initial raw data to a raw_bak folder, and then moves
	individual files into their respective series directory.
	
	<input_directory> Directory containing all raw dicom or ima
	files to process. Absolute path is recommended.

usageEOF
	exit $1
}

# If theres no argument or wrong number of args, return usage()
if [ $# -ne $MINARGS ]; then
	usage 10 1>&2
fi

# Grab the directory to process
rawPath=$1

# assume this is where the paths file is:
preproc=$( dirname $(which preproc.sh) )
if [ -e $preproc/paths.sh ] ; then
	source $preproc/paths.sh
else
	printf "\nERROR: $preproc/paths.sh not found. Make sure that the\n\
	preprocessing directory is in the global PATH environment var.\n\
	Check your .bashrc file or the config files in\n\
	/etc/profile.d/ named fidl.sh or fidl.csh\n"
fi

# Set path to medcon
if [ ! -d $(dirname $medcon) ]; then
	printf "\nERROR: $medcon not found.\n\n"
	exit 1
fi

pushd $rawPath >/dev/null

#----------------------------------------------------------------------
# Main
#----------------------------------------------------------------------
printf "\n-------------------------------------"
printf "\nSorting files into series directories"
printf "\n-------------------------------------"
printf "\n$PROGRAM: User $USER on $(date)\n"

# Set up some vars to count number of files processed, and number of errors
filecount=1

# Array of all files to process
files=( $(find ./?* -maxdepth 0 -type f) )

# Check for a backup directory; If it doesn't exist, create it and cp files
if [ ! -d $rawPath/raw_bak ]; then 
	mkdir "$rawPath/raw_bak"
	cp $rawPath/* raw_bak/ 2>/dev/null
fi

# iterate over all files in input directory
for (( i=0; i<${#files[@]}; i++ )); do
	
	# Pull out the series information
	ser=$( $medcon -f ${files[$i]} -fb-dicom -s -d | grep "Series Number" | awk '{print $4}')
		
	# Pad to three digits
	ser=$( printf %03d $ser )

	# If series dir doesn't exist yet, make it
	if [ ! -d $rawPath/$ser ]; then mkdir "$rawPath/$ser"; fi
	
	# Make sure the destination file doesn't exist yet
	if [ ! -e $rawPath/$ser/${files[$i]} ]; then
		# If destination file doesn't exist, move file
		mv ${files[$i]} $rawPath/$ser/
	else
		# If destination file exists, break
		printf "\nERROR: cannot move ${files[$i]}. Destination files already exists.\n"
		printf "Files could not be moved because the filename\n"
		printf "already exists in the destination directory.\n"
		printf "Please check for duplicate files.\n\n"
		popd >/dev/null
		exit 1
	fi
	
	# Return progress every 50 files	
	if [ "${filecount:(-2)}" == '00' ] || [ "${filecount:(-2)}" == '50' ]; then
		printf "\n$filecount of ${#files[@]} files processed\n"
	fi
	
	# Increment count of files processed
	(( filecount++ ))
	
	unset ser; 
done

# Fix filecount to true number processed
(( filecount-- ))
printf "\n${filecount} of ${#files[@]} files processed\n"

popd >/dev/null

printf "\n$PROGRAM: Finished - User $USER on $(date)\n"

# Exit safely
exit 0
