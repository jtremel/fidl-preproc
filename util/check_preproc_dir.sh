#!/bin/bash
#
#----------------------------------------------------------------------
# check_preproc_dir.sh
#
# Checks for data left over from a previous preprocessing; if it finds
# anything, you'll be asked if you want to remove it before continuing,
# otherwise, it'll exit and tell you to check your directory structure.
#
# Revision 1.1: JT
# 01.18.2012
#  Cleaned up the logic a bit so it actually works correctly.
#
# Version 1.0
# 11.14.2011
#
# Josh Tremel
# (tremeljosh@gmail.com)
# University of Pittsburgh
#----------------------------------------------------------------------

#----------------------------------------------------------------------
# Program and User info
#----------------------------------------------------------------------
COMMAND=$0
PROGRAM=check_preproc_dir.sh
VERSION=1.0
USER=$(whoami)

MINARGS=1

#----------------------------------------------------------------------
# Program Usage
#----------------------------------------------------------------------
usage() {
	cat << usageEOF
Usage: check_preproc_dir.sh <string vars_file>
Options: <none currently>
Description:
	description here
	
	<vars_file>

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

# Set up path variables for convenience
subjPath=${studyPath}/${subjID}
rawPath=${subjPath}/${rawDir}

#----------------------------------------------------------------------
# Main
#----------------------------------------------------------------------
printf "\n------------------------------------"
printf "\nChecking subject directory structure"
printf "\n------------------------------------"
printf "\n$PROGRAM: User $USER on $(date)\n"

# Push into subject directory
pushd $subjPath >/dev/null

# Check common directories, see if they're empty
if [ -d atlas ]; then hasAtlas=1; else hasAtlas=0 ; fi
if (( $hasAtlas == 1 )); then
	[ "$(ls -A atlas)" ]  && atlasFull=1 || atlasFull=0
else atlasFull=0
fi

if [ -d movement ]; then hasMovt=1; else hasMovt=0 ; fi
if (( $hasMovt == 1 )); then
	[ "$(ls -A movement)" ]  && movtFull=1 || movtFull=0
else movtFull=0
fi

if [ $(find ${funcLabel[*]} -type d 2>/dev/null | wc -l) -gt 0 ]; then
	hasBold=1
	boldDir=( $(find ${funcLabel[*]} -type d ) )
elif [ $(find bold? -type d 2>/dev/null | wc -l) -gt 0 ]; then
	hasBold=1
	boldDir=( $(find bold? -type d ) )
else
	hasBold=0
fi

if (( $hasBold == 1 )); then
	for (( i=0; i<${#boldDir[@]}; i++ )); do
		if [ "$(ls -A ${boldDir[$i]})" ]; then
			boldFull=( ${boldFull[*]} 1 )
			hasBold=1
		else
			boldFull=( ${boldFull[*]} 0 )
		fi
	done
else
	boldFull=0
	hasBold=0
fi

if [ $atlasFull -eq 1 -o $movtFull -eq 1 -o $hasBold -eq 1 ]; then
	printf "\nFound directories from a previous preprocessing run."
	printf "\nWould you like to remove them? (Y/n): "
	read answer

	if [ -z $answer ] ; then
		printf "\nFixing directories...\n"
	else
		case $answer in 
			[yY] | [yY][Ee][Ss] )
				printf "\nFixing directories...\n"
				;;
			[nN] | [N|n][O|o] )
				printf "Please check your directories and try again. Exiting...\n"
				exit 11
				;;
			*)
				printf "Unrecognized input. Please check your directories and try again. Exiting...\n"
				exit 12
				;;
		esac
	fi
fi

if [ $atlasFull -eq 1 ]; then
	printf "\nRemoving files from atlas/..."
	/bin/rm atlas/*
fi
if [ $movtFull -eq 1 ]; then
	printf "\nRemoving files from movement/..."
	/bin/rm movement/*
fi

if [ $hasBold -eq 1 ]; then
	printf "\nRemoving files from functional directories/..."
	for (( i=0; i<${#boldFull[@]}; i++ )); do
		if [ ${boldFull[$i]} -eq 1 ]; then
			/bin/rm ${boldDir[$i]}/*
		fi
	done
fi

# Check for and remove symbolic links in rawPath
if [ $(find $rawPath/* -type l | wc -l ) -gt 0 ]; then
	printf "\nRemoving links in Raw Directory...\n"
	find $rawPath/* -type l | xargs -i rm '{}'
fi

# Check for and remove those ridiculous need_analyze files from the MRRC
if [ $(find $rawPath/* -type f -name "need_analyze" | wc -l ) -gt 0 ]; then
	printf "\nRemoving need_analyze files...\n"
	find $rawPath/* -type f -name "need_analyze" | xargs -i rm '{}'
fi
# Check for and remove that equally ridiculous Phoenix zip report from the MRRC
if [ $(find $rawPath/* -type d -name "*Phoenix*" | wc -l) -gt 0 ]; then
	printf "\nRemoving Phoenix_Zip_Report dirs...\n"
	find $rawPath/* -type d -name "*Phoenix*" | xargs -i \rm -rf '{}'
fi

popd >/dev/null

printf "\n$PROGRAM: Finished - User $USER on $(date)\n\n"

# Exit safely
exit 0
