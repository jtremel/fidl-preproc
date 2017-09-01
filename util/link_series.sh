#!/bin/bash
#
#----------------------------------------------------------------------
# link_series.sh
# Creates a symbolic link for each series in the raw data directory
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

#----------------------------------------------------------------------
# Program and User info
#----------------------------------------------------------------------
COMMAND=$0
PROGRAM=link_series.sh
VERSION=1.1
USER=$(whoami)

MINARGS=1

#----------------------------------------------------------------------
# Program Usage
#----------------------------------------------------------------------
usage() {
	cat << usageEOF
	
Usage: link_series.sh <string input_directory>
Options: <none currently>
Description:
	Creates a symbolic link for each series in the raw data directory.
	
	<input_directory> Raw directory containing series dirs.

usageEOF
	exit $1
}

# If there's no argument, return usage
if [ $# -ne $MINARGS ]; then
	usage 10 1>&2
fi

# Grab the input directory
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
# Check if it exists; if not, exit with error
if [ ! -d $(dirname $medcon) ]; then
	printf "\nERROR: $medcon not found.\n\n"
	exit 1
fi

#----------------------------------------------------------------------
# Main
#----------------------------------------------------------------------
printf "\n------------------------------------"
printf "\nCreating links to series directories"
printf "\n------------------------------------"
printf "\n$PROGRAM: User $USER on $(date)\n"

# Push into raw data directory
pushd $rawPath >/dev/null

# Array of series directories, excluding "raw_bak" if it's there
dirList=( $(find ./?* -maxdepth 0 -type d | cut -d "/" -f2 | grep -v "raw_bak") )

# Make series links
for (( i=0; i<${#dirList[@]}; i++ )); do
	printf "\nCreating Link for ${dirList[$i]}\n"

	# Push into directory[i]
	pushd "${dirList[$i]}" >/dev/null

	# Pull the series number
	ser="$( $medcon -f `find *.sort.dcm -type l | head -1` -fb-dicom -s \
	-d | grep "Series Number" | awk '{print $4}' )"

	# Pad the series number
	ser=$(printf "%02d" $ser)
	
	# Pop from directory[i]
	popd >/dev/null

	# make link in inpath
	if [ ! -h $rawPath/$ser ]; then
		ln -s ${dirList[$i]} $rawPath/$ser
	fi
	
	unset ser
done

# Notify user that linking is finished
printf "\nLinks to series directories completed\n"

popd >/dev/null

printf "\n$PROGRAM: Finished - User $USER on `date`\n"

# Exit safely
exit 0

