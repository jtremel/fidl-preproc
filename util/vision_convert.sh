#!/bin/bash
#
#----------------------------------------------------------------
# vision_convert.sh
#  Processing stream for old Siemens Vision files. This will 
#  sort files into series directories, rename files, and convert
#  them to 4dfp. Note the conversion uses AFNI's to3d command to
#  convert to AFNI format, then 3dAFNItoANALYZE to convert to ANZ
#  and finally analyzeto4dfp to end up with a 4dfp.
#
# Version 1.2: JT
# 05.07.2013
#  Updated analyzeto4dfp to use the nil-tools RELEASE var instead
#   of a hard path.
#  Updated to work with new paths.sh file in main preproc dir
#
# Version 1.1: JT
# 11.07.2012
#  fixed the incorrect orientation flag being set in mprage IFHs
#  +NOTE: this is hard-coded to sagittal. Let me know if you are
#  +using a different orientation.
#
# Version 1.0
# 10.05.2011
#
# Josh Tremel
# (tremeljosh@gmail.com)
# University of Pittsburgh
#----------------------------------------------------------------

#----------------------------------------------------------------
# Program and User info
#----------------------------------------------------------------
COMMAND=$0
PROGRAM=vision_convert.sh
VERSION=1.2
USER=$(whoami)

MINARGS=2

#----------------------------------------------------------------
# Program Usage
#----------------------------------------------------------------
usage() {
	cat << usageEOF
	
Usage: sort_series.sh <str input_directory> <bool isSingleDir>
Options: <none currently>
Description:
	Processing stream for old Siemens Vision files. This will 
	sort files into series directories, rename files, and convert
	them to 4dfp. This script uses AFNIs to3d cmd to convert to 
	AFNI format, then 3dAFNItoANALYZE to convert to ANZ
	and finally analyzeto4dfp to end up with a 4dfp.
	
	<input_directory> Directory containing all raw files to process.
	Absolute path is recommended.

	<isSingleDir> True if all files are in the input_directory
	without series sub-directories. False if files are sorted into
	series directories in the parent input_directory.
	
usageEOF
	exit $1
}

# If theres no argument or wrong number of args, return usage()
if [ $# -ne $MINARGS ]; then
	usage 10 1>&2
fi

# Grab the directory to process
rawPath=$1

# Check if it's a single directory of files
isSingleDir=$2

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

# Check afni path
if [ ! -d $afni ]; then
	printf "\nERROR: $afni not found.\n\n"
	exit 1
fi

anzTo4dfp=$RELEASE/analyzeto4dfp
if [ ! -d $(dirname $anzTo4dfp) ]; then
	printf "\nERROR: $anzTo4dfp not found.\n\n"
	exit 1
fi

pushd ${rawPath} >/dev/null

#----------------------------------------------------------------------
# Sort files into series directories
#----------------------------------------------------------------------
if [ $isSingleDir == true ]; then
	printf "\n-------------------------------------"
	printf "\nSorting files into series directories"
	printf "\n-------------------------------------"
	printf "\n$PROGRAM: User $USER on $(date)\n"

	# Set up some vars to count number of files processed, and number of errors
	filecount=1

	# Array of all files to process
	files=( $(find ./?* -maxdepth 0 -type f) )

	# Check for a backup directory; If it doesn't exist, create it and cp files
	if [ ! -d ${rawPath}/raw_bak ]; then 
		mkdir "$rawPath/raw_bak"
		cp ${rawPath}/* raw_bak/ 2>/dev/null
	fi

	# iterate over all files in input directory
	for (( i=0; i<${#files[@]}; i++ )); do

		# Pull out series and sequence information
		ser=$($afni/siemens_vision ${files[$i]} | grep "SubjectID" | awk '{print $2}')
		seq=$($afni/siemens_vision ${files[$i]} | grep "Sequence" | awk '{print $3}')

		serName="${ser}_${seq}"

		# If series dir doesn't exist yet, make it
		if [ ! -d $rawPath/$serName ]; then
			mkdir "$rawPath/$serName"
			printf "\nSeries Directory $serName created...\n"
		fi

		# Make sure the destination file doesn't exist yet
		if [ ! -e $rawPath/$serName/${files[$i]} ]; then
			# If destination file doesn't exist, move file
			mv ${files[$i]} ${rawPath}/${serName}/${files[$i]}
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

		unset serName; unset time; unset seq
	done

	# Fix filecount to true number processed
	(( filecount-- ))
	printf "\n$filecount of ${#files[@]} files processed\n"

	printf "\nFinished sorting files into series folders\n"
	printf "User $USER on $(date)\n"
	
fi

#----------------------------------------------------------------------
# Create sortable links to files
#----------------------------------------------------------------------
printf "\n--------------------------------"
printf "\nCreating sortable links to files"
printf "\n--------------------------------"
printf "\n$PROGRAM: User $USER on $(date)\n"

# Array of series directories, excluding "raw_bak" if it's there
dirList=( $(find ./?* -maxdepth 0 -type d | cut -d "/" -f2 | grep -v "raw_bak") )

# Iterate through the directories
for (( i=0; i<${#dirList[@]}; i++ )); do
	# Push into directory
	pushd ${dirList[$i]} >/dev/null
	
	# Grab files to process
	files=( $(find ./?* -maxdepth 0 -type f) )
	
	# Return progress, n files found in current directory
	printf "\nLinking ${#files[@]} files in ${dirList[$i]}\n"
	
	# Iterate through the files in current directory
	for (( j=0; j<${#files[@]}; j++ )); do
		# Pull out series, acquisition, instance information
		seq=$($afni/siemens_vision ${files[$j]} | grep "Sequence" | awk '{print $3}')
		imgNum=$($afni/siemens_vision ${files[$j]} | grep "ImageNum" | awk '{print $3}')

		# Pad values so they sort better
		imgNum=$(printf %04d $imgNum)

		# Concatenate string for new name, add ".sort.dcm" extension
		newName="${seq}_${imgNum}.vision.ima"

		# Make sure link does not exist
		if [ ! -h $newName ]; then
			# If there's no link yet, make it
			ln -s ${files[$j]} $newName
		else
			# If link exists, throw out warning
			printf "\nWARNING: link to $newName already exists; do you have duplicate files?\n"
			printf "Files could not be moved because the filename\n"
			printf "already exists in the destination directory.\n"
			printf "Please check for duplicate files.\n\n"
			exit 1
		fi
		unset seq; unset imgNum; unset newName
	done
	unset files

	popd >/dev/null
done

printf "\nLinking Finished: User $USER on $(date)\n"

#----------------------------------------------------------------------
# Find and convert mp-rage files
#----------------------------------------------------------------------
printf "\n------------------------"
printf "\nConverting Files to 4dfp"
printf "\n------------------------"
printf "\n$PROGRAM: User $USER on $(date)\n"

# Search for an "mpr" series
mprDir=( $(ls -1 | grep mpr) )
if [ -z $mprDir ]; then 
	printf "\nERROR: Cannot find an mprage directory\n"
	exit 1
fi
if (( ${#mprDir[@]} > 1 )); then
	printf "\nWARNING: Found multiple mprage directories. Using the first...\n"
	$mprDir=${mprDir[0]}
fi

pushd $mprDir >/dev/null
	printf "\nConverting MPRAGE..."
	# Convert and stack to AFNI format
	$afni/to3d -prefix mprage $(ls -1 *.vision.ima) &>/dev/null

	# Convert from AFNI to ANZ
	$afni/3dAFNItoANALYZE -4D mprage mprage+orig &>/dev/null

	# Convert ANZ to 4dfp, flip image to normal orientation
	#+ -O5 sets the orientation code to sagital
	#+ -x flips the image so it right-side-up and looking to the right
	$anzTo4dfp -O5 -x mprage >/dev/null

	# rm intermediates
	/bin/rm "mprage.hdr" ; /bin/rm "mprage.img"
	/bin/rm "mprage+orig.BRIK" ; /bin/rm "mprage+orig.HEAD"

#pop from mpr directory
popd >/dev/null

if [ ! -d ../atlas ]; then mkdir ../atlas ; fi
/bin/mv "${mprDir}/mprage.4dfp.hdr" "../atlas/"
/bin/mv "${mprDir}/mprage.4dfp.img" "../atlas/"
/bin/mv "${mprDir}/mprage.4dfp.ifh" "../atlas/"
/bin/mv "${mprDir}/mprage.4dfp.img.rec" "../atlas/"

printf "\nFinished.\n"

#----------------------------------------------------------------------
# Find and convert Functional images
#----------------------------------------------------------------------
# Search for "bold" series
boldDir=( $(find *bold* -maxdepth 0 -type d) )

# if no bolds were found, exit...
if [ -z $boldDir ]; then 
	printf "\nERROR: Cannot find an mprage directory\n"
	exit 1
fi

# if number of bolds is over 9, we'll have to fix the sort order...
if (( ${#boldDir[@]} > 9 )); then
	# Use GNU ls -v option to sort nicely.
	# FIXME: This doesn't work on all systems... kind of a hack...
	boldDir=( $(ls -v | grep bold) )
fi

# Loop through all bold directories
for (( i=0; i< ${#boldDir[@]}; i++ )); do
	printf "\nStacking and converting images in ${boldDir[$i]}...\n"
	pushd ${boldDir[$i]} >/dev/null
	
	# Array of files in this boldDir[i]
	filelist=( $(ls -1 *.vision.ima) )
	
	# Make a name for this (index + 1, padded to two digits)
	boldName=bold$( printf %02d $(( i + 1 )) )
	
	# AFNIs siemens_vision program conveniently outputs a compatible to3d
	#+ command for vision files. We don't need everything there and need
	#+ to add some options, so grab it (save to to3dcmd). Use awk to parse
	#+ and grab the parameters we need.
	to3dcmd=`echo "$($afni/siemens_vision ${filelist[$i]} | tail -1 )"`
	typeflag=$( echo $to3dcmd | awk '{print $2}' )
	timeflag=$( echo $to3dcmd | awk '{print $3}' )
	slices=$( echo $to3dcmd | awk '{print $4}' )
	slctime=$( echo $to3dcmd | awk '{print $6}' )
	altz=$( echo $to3dcmd | awk '{print $7}' )
	# Assemble our to3d command, run it, pipe all output to /dev/null
	#+ (We do this because, for some reason, to3d doesn't like Vision
	#+ epi images in a mosaic. It handles them and converts them 
	#+ perfectly, but likes to yell a bit [using both stderr and stdout]
	#+ about outliers while doing so...)
	$afni/to3d $typeflag $timeflag $slices ${#filelist[@]} $slctime $altz -sinter -prefix afni_${boldName} ${filelist[*]} &>/dev/null

	# Clear up some temp variables
	unset filelist; unset to3dcmd; unset typeflag; unset timeflag; unset slices; unset slctime; unset altz
	
	# Convert to analyze format. 4D flag tells it we're dealing with a stack
	#+ of epi/functional images with a time dimension
	$afni/3dAFNItoANALYZE -4D $boldName afni_$boldName+orig &>/dev/null
	
	# Convert to 4dfp. -yz flag flips image so Right=Right and stack goes Inf->Sup
	$anzTo4dfp -yz $boldName >/dev/null
	
	# rm intermediates
	/bin/rm "afni_$boldName+orig.BRIK" ; /bin/rm "afni_$boldName+orig.HEAD"
	/bin/rm "$boldName.hdr" ; /bin/rm "$boldName.img"

	# Pop from current bold directory
	popd >/dev/null
	
	# Move bold files to a directory in $subjDir
	if [ ! -d ../$boldName ]; then mkdir ../$boldName ; fi
	/bin/mv "${boldDir[$i]}/${boldName}.4dfp.hdr" "../$boldName/"
	/bin/mv "${boldDir[$i]}/${boldName}.4dfp.img" "../$boldName/"
	/bin/mv "${boldDir[$i]}/${boldName}.4dfp.ifh" "../$boldName/"
	/bin/mv "${boldDir[$i]}/${boldName}.4dfp.img.rec" "../$boldName/"

	unset boldName
	printf "\nFinished.\n"
done

# Get rid of all those links we set up
printf "\nCleaning up raw data directories...\n"
find * -type l | xargs rm

# return to original directory
popd >/dev/null

printf "\n$PROGRAM: Finished - User $USER on $(date)\n\n"

# Exit safely
exit 0
