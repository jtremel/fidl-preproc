#!/bin/bash
#
#----------------------------------------------------------------------
# convert_dcmto4dfp.sh
# Converts dicom 3.0 compatible files to 4dfp, by way of the analyze
# image format.
#
# NOTE: This is a wrapper script for the standard preprocessing stream.
#
# Revision 1.3: JT
# 03.06.2017
#  Removed medcon dependency -- now using NIL dcm_to_4dfp program to
#   get files into 4dfp format
#
# Revision 1.2: JT
# 05.07.2013
#  Updated the analyzeto4dfp path to use the nil-tools RELEASE variable
#   instead of a hard path.
#  Updated to work with the new paths.sh file in the main preproc dir.
#
# Revision 1.1: JT
# 01.18.2012
#  Added logic to determine orientation of mp-rage, so
#   analyzeto4dfp will now flip the images correctly.
#  Added loop to find the real raw directory in case the specified dir
#   is just the top dir. For example, if user species 'raw', but data
#   are actually in raw/MRCTR/.
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
PROGRAM=convert_dcmto4dfp.sh
VERSION=1.3
USER=$(whoami)

MINARGS=1

#----------------------------------------------------------------------
# Program Usage
#----------------------------------------------------------------------
usage() {
	cat << usageEOF
	
Usage: convert_dcmto4dfp.sh <string vars_file>
Description:
	Converts DICOM 3.0 standard files to analyze format and
	then to 4dfp for use with fidl.
	
	<vars_file> Preproc v2.0 vars file (usually passed from the actual
	preprocessing script)

usageEOF
	exit $1
}

# If there's no argument, return usage
if [ $# -ne $MINARGS ]; then
	usage 10 1>&2
fi

# Grab the vars file
varsFile=$1
# Read in variables
source $varsFile

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

# Set path to dcm_to_4dfp; check that it exists
dcmTo4dfp=$RELEASE/dcm_to_4dfp
if [ ! -d $(dirname $dcmTo4dfp) ]; then
	printf "\nERROR: $dcmTo4dfp not found. Check that nil-tools RELEASE env var is set.\n\n"
	exit 1
fi

unpack4dfp=$RELEASE/unpack_4dfp
if [ ! -d $(dirname $unpack4dfp) ]; then
	printf "\nERROR: $unpack4dfp not found. Check that nil-tools RELEASE env var is set.\n\n"
	exit 1
fi

# Set up path variables for convenience
subjPath=${studyPath}/${subjID}
rawPath=${subjPath}/${rawDir}

# Push into subject directory
pushd $subjPath >/dev/null

# See if atlas dir exists; if not, make it
if [ ! -d $subjPath/atlas ]; then mkdir $subjPath/atlas ; fi

#----------------------------------------------------------------------
# Find the real raw directory if it seems like specified is not right.
# Traverse directories until we hit some ambiguity
#----------------------------------------------------------------------
hasRawPath=1
curDir=$(pwd)
cd $rawPath > /dev/null
while [ $hasRawPath -eq 1 ]; do
	nDirs=$( find * -maxdepth 0 -type d | wc -l )
	nFiles=$( find * -maxdepth 0 -type f | wc -l )
	# If there's only one directory and no files, keep going...
	if [ $nDirs -eq 1 -a $nFiles -eq 0 ]; then
		cd $( find * -maxdepth 0 -type d ) >/dev/null
		rawPath=$(pwd)
	else
		hasRawPath=0
		cd $curDir >/dev/null
	fi
	unset nDirs; unset nFiles
done
unset curDir; unset hasRawPath

#----------------------------------------------------------------------
# CONVERT MPRAGE
#----------------------------------------------------------------------
# Check if there's a t1/mprage
if [ -n $t1Series ]; then
	printf "\n------------------"
	printf "\nConverting MP-RAGE"
	printf "\n------------------"
	printf "\nUser $USER on $(date)\n"
	
	# Pad series number to three digits
	mprDir=$(printf %03d ${t1Series})
		
	# Set full path to t1 raw series directory
	mprDir=$(printf ${rawPath}/${mprDir})
	printf "\nConverting MP-RAGE dicoms to 4dfp from $mprDir\n"
	
	# Convert mprage from dcm files
	$dcmTo4dfp -b atlas/${subjID}_mprage ${mprDir}/*.dcm

	# Make sure exit status of command was 0 (i.e., successful, no errors).
	#+	If not, exit with error.
	if (( $? > 0 )); then 
		printf "\n$PROGRAM: DCM_TO_4DFP ERROR\n"
		exit 1
	fi
fi

#----------------------------------------------------------------------
# CONVERT T2
#----------------------------------------------------------------------
# Check if there's a t2 structural
if [ ! -z $t2Series ]; then
	printf "\n-------------"
	printf "\nConverting T2"
	printf "\n-------------"
	printf "\nUser $USER on $(date)\n"
	
	# Pad series number to three digits
	t2Dir=$(printf %03d ${t2Series})
	
	# Set full path to t2 raw series directory
	t2Dir=$(printf ${rawPath}/${t2Dir})
	printf "\nConverting T2 dicoms to 4dfp from $t2Dir\n"

	# Convert T2 from dcm files
	#+ DCM_TO_4DFP automatically flips image to be in neuropsych orientation (img R = real R)
	$dcmTo4dfp -b atlas/${subjID}_t2w ${t2Dir}/*.dcm

	# Make sure exit status of command was 0 (i.e., successful, no errors). Else, exit w/ error
	if (( $? > 0 )); then 
		printf "\n$PROGRAM: DCM_TO_4DFP ERROR\n"
		exit 1
	fi
fi

#----------------------------------------------------------------------
# CONVERT FUNCTIONAL DATA
#----------------------------------------------------------------------
printf "\n--------------------------"
printf "\nConverting Functional Data"
printf "\n--------------------------"
printf "\nUser $USER on $(date)\n"

# Loop across all functional runs
for (( i=0; i<${#funcSeries[@]}; i++ )); do
	printf "\nConverting Series $( printf %02d ${funcSeries[$i]} )...\n"
	
	# If directory 'Label[index]' doesn't exist, make it.
	if [ ! -d ${funcLabel[$i]} ]; then mkdir ${funcLabel[$i]}; fi
	
	# Pad series number to three digits
	curSeriesDir=$( printf %03d ${funcSeries[$i]} )
	
	# Set full path to raw functional data directory
	curSeriesDir=$( printf ${rawPath}/${curSeriesDir} )
	printf "\nConverting EPI dicom files to 4dfp from $curSeriesDir\n"
	
	# Check if we need to evict any images 
	#+	(awk "FNR>2", for example, will print out the full list minus the first two images)
	if (( $evict > 0 )); then
		fileList=( $(ls -1 ${curSeriesDir}/*.dcm | awk "FNR>$evict") )
	else
		fileList=( $(ls -1 ${curSeriesDir}/*.dcm) )
	fi
	
	
	# Convert EPI data from dcm files
	#+ DCM_TO_4DFP automatically flips image to be in neuropsych orientation (img R = real R)
	dcm_to_4dfp -b ${subjPath}/${funcLabel[$i]}/${subjID}"_"${funcLabel[$i]}"_raw" ${fileList[*]}

	# Make sure exit status of command was 0 (i.e., successful, no errors). Else, exit w/ error
	if (( $? > 0 )); then 
		printf "\n$PROGRAM: DCM_TO_4DFP ERROR\n"
		exit 1
	fi

	# Unpack the mosaic into 4D slices
	printf "\nUnpacking EPI mosaic\n"
	$unpack4dfp -z -V ${subjPath}/${funcLabel[$i]}/${subjID}"_"${funcLabel[$i]}"_raw" ${subjPath}/${funcLabel[$i]}/${subjID}"_"${funcLabel[$i]}

	# Make sure exit status of command was 0 (i.e., successful, no errors). Else, exit w/ error
	if (( $? > 0 )); then 
		printf "\n$PROGRAM: UNPACK_4DFP ERROR\n"
		exit 1
	fi

	# Clean up 
	/bin/rm ${subjPath}/${funcLabel[$i]}/${subjID}"_"${funcLabel[$i]}"_raw.4dfp."*

	# clear variables before increment
	unset fileList; unset curSeriesDir
done

# Notify user that we're done
printf "\nConversions completed\n"

popd >/dev/null

# Program info and time
printf "\n$PROGRAM: Finished - User $USER on $(date)\n"

# Exit safely
exit 0
