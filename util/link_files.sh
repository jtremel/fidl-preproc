#!/bin/bash
#
#----------------------------------------------------------------------
# link_files.sh
# Pulls info from dicom/ima files and creates a symbolic link
# with a sortable filename: <series>_<acquisition>_<instance>.dcm
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
PROGRAM=link_files.sh
VERSION=1.1
USER=$(whoami)

MINARGS=1

#----------------------------------------------------------------
# Program Usage
#----------------------------------------------------------------
usage() {
	cat << usageEOF
Usage: link_files.sh <string input_directory>
Options: <none currently>
Description:
	Creates a symbolic link for arbitrarily-named dicom or ima
	files. The link name is sortable by series, acquisition, and
	instance and will have a .sort.dcm "extension". Other scripts
	(e.g., convert_dcmto4dfp.sh) depend on input files having
	this extension (in other words, run this first).
	
	<input_directory> Raw directory containing series dirs. The
	files to link should be in these series directories. Using
	absolute path is recommended.

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

# Make sure it exists; if not, exit with error
if [ ! -d $(dirname $medcon) ]; then
	printf "\nERROR: $medcon not found.\n\n"
	exit 1
fi

#----------------------------------------------------------------------
# Main
#----------------------------------------------------------------------
printf "\n--------------------------------"
printf "\nCreating sortable links to files"
printf "\n--------------------------------"
printf "\n$PROGRAM: User $USER on $(date)\n"
printf "\nThis might take a little while; please be patient."
printf "\nDo not interrupt or kill this process.\n"

pushd $rawPath >/dev/null

# Array of series directories, excluding "raw_bak" if it's there
dirList=($(find ./?* -maxdepth 0 -type d | cut -d "/" -f2 | grep -v "raw_bak"))

# Iterate through the directories
for (( i=0; i<${#dirList[@]}; i++ )); do
	# Push into directory[i]
	pushd ${dirList[$i]} >/dev/null
	
	# Grab files to process
	files=( $(find ./?* -maxdepth 0 -type f) )
	
	# Return progress, n files found in current directory
	printf "\nLinking ${#files[@]} files in ${dirList[$i]}\n"

	# Iterate through the files in current directory
	for (( j=0; j<${#files[@]}; j++ )); do
		# Pull out series, acquisition, instance information
		ser=$( $medcon -f ${files[$j]} -fb-dicom -s -d | grep "Series Number" | awk '{print $4}' )
		acq=$( $medcon -f ${files[$j]} -fb-dicom -s -d | grep "Acquisition Number" | awk '{print $4}' )
		ins=$( $medcon -f ${files[$j]} -fb-dicom -s -d | grep "Image Number" | awk '{print $4}' )

		# Pad values so they sort better
		ser=$(printf %02d $ser)
		acq=$(printf %04d $acq)
		ins=$(printf %06d $ins)

		# Concatenate string for new name, add ".sort.dcm" extension
		newName="${ser}_${acq}_${ins}.sort.dcm"

		# Make sure link does not exist; if not, make it.
		if [ ! -h $newName ]; then
			ln -s ${files[$j]} $newName
		else
			# If destination file exists, exit with error
			printf "\nERROR: cannot link ${files[$j]}. Destination file already exists.\n"
			printf "Files could not be moved because the filename\n"
			printf "already exists in the destination directory.\n"
			printf "Please check for duplicate files.\n\n"
			popd >/dev/null
			exit 1
		fi
		unset ser; unset acq; unset ins; unset newName
		
		if [ "${j:(-2)}" == '00' ] || [ "${j:(-2)}" == '50' ]; then
			printf "\t$j files linked...\n"
		fi
	done
	unset files

	popd >/dev/null
done

# Notify user that linking is finished
printf "\nLinking finished\n"

popd >/dev/null

printf "\n$PROGRAM: Finished - User $USER on $(date)\n"

# Exit safely
exit 0
