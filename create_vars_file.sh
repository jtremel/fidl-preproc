#! /bin/bash
#
#----------------------------------------------------------------------
# create_vars_file.sh
#
# Creates a subj.vars file for use with preproc v2.0 and later.
#
# Revision 1.1: JT
# 10.26.2011
#  added incrementing series numbers for funcs/labels
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
PROGRAM=create_vars_file.sh
VERSION=1.1
USER=$(whoami)

#----------------------------------------------------------------
# Function for an editable prompt
#----------------------------------------------------------------
exec 4>/dev/tty
function editprompt
{
        local prompt=$1
        local init=$2
        local backspace=$(echo -e \\b\\c)
        local enter=$(echo -e \\r\\c)
        local savesetting=$(stty -g)
        local keystroke data n i rest reading result
        n=0
        while (( ${#init})) ; do
                rest=${init#?}
                data[n]=${init%$rest}
                init=$rest
                ((n=n+1))
        done
        echo -e "${prompt}"\\c >&4
        while  ((i<n)) ; do
                echo -e ${data[i]}\\c >&4
                ((i=i+1))
        done
        stty -echo -icrnl -icanon min 1 time 0
        reading=1
        while ((reading)) ; do
                keystroke=$(dd bs=1 count=1 2>/dev/null)
                case $keystroke in
                $enter)
                        reading=0
                        ;;
                $backspace)
                        if ((n)) ; then
                                echo -e "${backspace} ${backspace}"\\c >&4
                                ((n=n-1))
                        fi
                        ;;
                *)
                        echo -e ${keystroke}\\c >&4
                        data[n]=$keystroke
                        ((n=n+1))
                esac
        done
        stty "$savesetting"
        echo >&4
        result=""
        i=0
        while  ((i<n)) ; do
                result="${result}${data[i]}"
                ((i=i+1))
        done
        echo $result
        return 0
}

#----------------------------------------------------------------
# Get settings and variables from the user...
#----------------------------------------------------------------
pushd .. >/dev/null
studyPath=$(pwd)
popd > /dev/null

echo ""
echo "----------------------------------------------------------------"
echo " Main Study Directory (where your subject folders are)"
echo "----------------------------------------------------------------"
studyPath=$(editprompt "Enter study directory: " $studyPath)
echo ""

echo "----------------------------------------------------------------"
echo " Subject ID (name of subject directory):"
echo "----------------------------------------------------------------"
subjID=$(editprompt "Subject ID: " )
echo ""

echo $subjID

echo "----------------------------------------------------------------"
echo " Raw Data Directory (in subject directory)"
echo "  (standard lab use: raw)"
echo "----------------------------------------------------------------"
rawDir=$(editprompt "Raw data directory is called: " raw)
echo ""

echo "----------------------------------------------------------------"
echo " Target Atlas:"
echo "  (standard lab use: 711-2B or 711-2C)"
echo "----------------------------------------------------------------"
target=$(editprompt "Name of target atlas: " 711-2B)

if [ $target == "711-2B" -o $target == "711-2C" -o $target == "711-2O" ] ; then
	echo "Atlas recognized..."
else
	echo "Atlas not recognized..."
	echo ""
	echo "----------------------------------------------------------------"
	echo " If this is a custom atlas, where is it? (use full path)"
	echo "----------------------------------------------------------------"
	targetPath=$(editprompt "Please specify the full path to dir containing target atlas: " /usr/local/pkg/fidl/lib)
fi
echo ""

echo "----------------------------------------------------------------"
echo " MP-RAGE or T1 structural sequence number"
echo "----------------------------------------------------------------"
t1Series=( $(editprompt "MP-RAGE series number: " 4) )
echo ""
answer=$(editprompt "Do you have more than one mprage? [y/n]? " n)
if [ $answer == "y" ]; then 
	isDone=false
	while [ $isDone == "false" ]; do
		t1Series=( ${t1Series[*]} $(editprompt "Next MP-RAGE series: " 5))
		echo ""
		finished=$(editprompt "Add another [y/n]? " n)
		if [ $finished == "n" ]; then
			isDone=true
		fi
	done
fi
echo ""

echo "----------------------------------------------------------------"
echo " T2-weighted structural series number"
echo "----------------------------------------------------------------"
t2Series=$(editprompt "T2w series number: " 3)
echo ""

echo "----------------------------------------------------------------"
echo " Functional Series Numbers and Labels"
echo "----------------------------------------------------------------"
funcSeries=( $(editprompt "First functional series number: " $(( ${t1Series[0]}+1 )) ) )
echo ""
isDone=false
while [ $isDone == "false" ]; do
	funcSeries=( ${funcSeries[*]} $(editprompt "Next Functional Series: " $(( ${funcSeries[$((${#funcSeries[@]}-1))]}+1 )) ))
	echo ""
	addAnother=$(editprompt "Add another [y/n]? " n)
	if [ $addAnother == "n" ]; then
		isDone=true
	fi
done
for (( i=0; i<${#funcSeries[@]}; i++ )); do
	funcLabel=( ${funcLabel[*]} $(editprompt "Label for Functional Series ${funcSeries[$i]}: " run$(($i+1))) )
done
echo ""

echo "----------------------------------------------------------------"
echo " Image Dimensions (standard X and Y is 64x64)"
echo "----------------------------------------------------------------"
xDim=$(editprompt "X dimension for functional volumes [standard = 64]: " 64)
yDim=$(editprompt "Y dimension for functional volumes [standard = 64]: " 64)
zDim=$(editprompt "Number of slices for functionals [Z dimension]: " 38)
echo ""
TR=$(editprompt "TR [in seconds]: " 2.0)
echo ""
slcTR=$(editprompt "TR time per slice in seconds [standard: 0, assumes even spacing]: " 0)
echo ""

echo "----------------------------------------------------------------"
echo " Skip and Evict"
echo "  (standard is 0 for both)"
echo "  Skip is frames that will be ignored"
echo "  Evict is number of frames that will be kicked out entirely"
echo "----------------------------------------------------------------"
skip=$(editprompt "Number of pre-functional frames to SKIP in preprocessing: " 0)
evict=$(editprompt "Number of pre-functional frames to EVICT in preprocessing: " 0)
echo ""

echo "----------------------------------------------------------------"
echo " Atlas Transform Settings"
echo "    0: leave processed time series in EPI data space."
echo "    1: transform entire data stack to atlas space"
echo "       in a single resampling (Note: takes up a lot of space...)"
echo "    2: proceed directly to t4_xr3d_4dfp"
echo "  (standard lab use: 0)"
echo "----------------------------------------------------------------"
epi2atl=$(editprompt "When would you like to transform to atlas space: " 0)
echo ""
if (( $epi2atl != 0 )); then
	atlSpace=$(editprompt "Which atlas space do you want to use [111, 222, 333]: " 222 )
else
	atlSpace=222
fi
echo ""

echo "----------------------------------------------------------------"
echo " Normalization"
echo "    1: enable per-frame volume intensity equalization"
echo "    0: no operation"
echo "  (standard lab use: 1)"
echo "----------------------------------------------------------------"
shouldNorm=$(editprompt "Do you want to normalize per-frame volume intensity? " 1)
echo ""

echo "----------------------------------------------------------------"
echo " Economy Setting"
echo "    econ = 0    keep all intermediate files"
echo "    econ = 2    rm ANALYZE format images"
echo "    econ = 3    + rm raw bold 4dfp stacks"
echo "    econ = 4    + rm frame-aligned stacks"
echo "    econ = 5    + rm debanded stacks (if epi2atl is 0)"
echo "    econ = 6    + rm raw data-space mprage files"
echo "    econ = 7    + rm cross-registered and normalized stacks"
echo "  (standard lab use: 5)"
echo "----------------------------------------------------------------"
econ=$(editprompt "Economy Setting: " 5)
echo ""

#----------------------------------------------------------------
# Make the file
#+ (This is a pretty lazy way of doing this; just redirect a 
#+ bunch of stuff to the file...)
#----------------------------------------------------------------
if [ -e ${subjID}.vars ]; then /bin/rm ${subjID}.vars ; fi

varsFile="${subjID}.vars"
touch $varsFile

printf "#////////////////////////////////////////////////////////////////\n" >>$varsFile
printf "#      VARIABLES AND SETTINGS FILE FOR FIDL PREPROC STREAM\n" >>$varsFile
printf "#////////////////////////////////////////////////////////////////\n" >>$varsFile
printf "#----------------------------------------------------------------\n" >>$varsFile
printf "# Main study directory (where your subject folders are):\n" >>$varsFile
printf "#----------------------------------------------------------------\n" >>$varsFile
printf "studyPath=$studyPath\n\n" >>$varsFile
printf "#----------------------------------------------------------------\n" >>$varsFile
printf "# Subject ID (name of subject directory):\n" >>$varsFile
printf "#----------------------------------------------------------------\n" >>$varsFile
printf "subjID=$subjID\n\n" >>$varsFile
printf "#----------------------------------------------------------------\n" >>$varsFile
printf "# raw data directory is called (in subject directory):\n" >>$varsFile
printf "# (Standard lab use: raw)\n" >>$varsFile
printf "#----------------------------------------------------------------\n" >>$varsFile
printf "rawDir=$rawDir\n\n" >>$varsFile
printf "#----------------------------------------------------------------\n" >>$varsFile
printf "# Target atlas:\n" >>$varsFile
printf "# (Standard lab use: 711-2B or 711-2C)\n" >>$varsFile
printf "#----------------------------------------------------------------\n" >>$varsFile
printf "target=$target\n\n" >>$varsFile
printf "#----------------------------------------------------------------\n" >>$varsFile
printf "#   If this is a custom atlas, where is it? (use full path)\n" >>$varsFile
printf "#       (leave blank if you're using a default atlas)\n" >>$varsFile
printf "#----------------------------------------------------------------\n" >>$varsFile
printf "targetPath=$targetPath\n\n" >>$varsFile
printf "#----------------------------------------------------------------\n" >>$varsFile
printf "# MP-RAGE/T1 structural sequence series number:\n" >>$varsFile
printf "#----------------------------------------------------------------\n" >>$varsFile
printf "t1Series=( ${t1Series[*]} )\n\n" >>$varsFile
printf "#----------------------------------------------------------------\n" >>$varsFile
printf "# T2-weighted structural sequence series number:\n" >>$varsFile
printf "#----------------------------------------------------------------\n" >>$varsFile
printf "t2Series=( ${t2Series[*]} )\n\n" >>$varsFile
printf "#----------------------------------------------------------------\n" >>$varsFile
printf "# Label each functional run\n" >>$varsFile
printf "# Place corresponding series numbers underneath\n" >>$varsFile
printf "#----------------------------------------------------------------\n" >>$varsFile
printf "funcLabel=( ${funcLabel[*]} )\n\n" >>$varsFile
printf "funcSeries=( ${funcSeries[*]} )\n\n" >>$varsFile
printf "#----------------------------------------------------------------\n" >>$varsFile
printf "# Repetition time (TR) in seconds\n" >>$varsFile
printf "# (Standard lab use: 2.0)\n" >>$varsFile
printf "#----------------------------------------------------------------\n" >>$varsFile
printf "TR=$TR\n\n" >>$varsFile
printf "#----------------------------------------------------------------\n" >>$varsFile
printf "# TR time per slice in seconds; 0 assumes even spacing\n" >>$varsFile
printf "# (Standard lab use: 0)\n" >>$varsFile
printf "#----------------------------------------------------------------\n" >>$varsFile
printf "slcTR=$slcTR\n\n" >>$varsFile
printf "#----------------------------------------------------------------\n" >>$varsFile
printf "# X dimension for functional volumes\n" >>$varsFile
printf "# (Standard lab use: 64)\n" >>$varsFile
printf "#----------------------------------------------------------------\n" >>$varsFile
printf "xDim=$xDim\n\n" >>$varsFile
printf "#----------------------------------------------------------------\n" >>$varsFile
printf "# Y dimension for functional volumes\n" >>$varsFile
printf "# (Standard lab use: 64)\n" >>$varsFile
printf "#----------------------------------------------------------------\n" >>$varsFile
printf "yDim=$yDim\n\n" >>$varsFile
printf "#----------------------------------------------------------------\n" >>$varsFile
printf "# Number of slices for functionals\n" >>$varsFile
printf "# (Standard lab use: 38)\n" >>$varsFile
printf "#----------------------------------------------------------------\n" >>$varsFile
printf "zDim=$zDim\n\n" >>$varsFile
printf "#----------------------------------------------------------------\n" >>$varsFile
printf "# Number of pre-functional frames to ignore while processing\n" >>$varsFile
printf "# (Standard lab use: 0)\n" >>$varsFile
printf "#----------------------------------------------------------------\n" >>$varsFile
printf "skip=$skip\n\n" >>$varsFile
printf "#----------------------------------------------------------------\n" >>$varsFile
printf "# Number of pre-functional frames to permanently evict\n" >>$varsFile
printf "#    Note: this is not additional to 'skip'; e.g., if skip is 2\n" >>$varsFile
printf "#    and evict is 2, 2 frames will be kicked out entirely, and\n" >>$varsFile
printf "#    0 frames will be skipped.\n" >>$varsFile
printf "# (Standard lab use: 0)\n" >>$varsFile
printf "#----------------------------------------------------------------\n" >>$varsFile
printf "evict=$evict\n\n" >>$varsFile
printf "#----------------------------------------------------------------\n" >>$varsFile
printf "# When would you like to transform to atlas space?\n" >>$varsFile
printf "#   0: leave processed time series in EPI/data space.\n" >>$varsFile
printf "#   1: transform to 222 space (i.e., transform entire bold\n" >>$varsFile
printf "#      stack to atlas space in a single resampling).\n" >>$varsFile
printf "#   2: proceed directly to t4_xr3d_4dfp.\n" >>$varsFile
printf "# (Standard lab use: 0)\n" >>$varsFile
printf "#----------------------------------------------------------------\n" >>$varsFile
printf "epi2atl=$epi2atl\n\n" >>$varsFile
printf "#----------------------------------------------------------------\n" >>$varsFile
printf "# if epi2atl is not 0, which atlas space do you want to use?\n" >>$varsFile
printf "# (111, 222, or 333)\n" >>$varsFile
printf "# (Standard lab use: 222)\n" >>$varsFile
printf "#----------------------------------------------------------------\n" >>$varsFile
printf "atlSpace=$atlSpace\n\n" >>$varsFile
printf "#----------------------------------------------------------------\n" >>$varsFile
printf "# Enable per-frame volume intensity equalization (normalization)\n" >>$varsFile
printf "# (1=yes, 0 for no operation) \n" >>$varsFile
printf "# (Standard lab use: yes)\n" >>$varsFile
printf "#----------------------------------------------------------------\n" >>$varsFile
printf "shouldNorm=$shouldNorm\n\n" >>$varsFile
printf "#----------------------------------------------------------------\n" >>$varsFile
printf "# Economy setting:  (Standard lab use: 5)\n" >>$varsFile
printf "#   econ = 0        keep all intermediates\n" >>$varsFile
printf "#   econ = 2        rm anz copies of images\n" >>$varsFile
printf "#   econ = 3        + rm raw bold 4dfp stacks\n" >>$varsFile
printf "#   econ = 4        + rm frame aligned stacks\n" >>$varsFile
printf "#   econ = 5        + rm debanded stacks (if epi2atl = 0)\n" >>$varsFile
printf "#   econ = 6        + rm raw mprage\n" >>$varsFile
printf "#   econ = 7        + rm x-reg 3d and normalized stacks\n" >>$varsFile
printf "#----------------------------------------------------------------\n" >>$varsFile
printf "econ=$econ\n\n" >>$varsFile

printf "\n\n$PROGRAM: Generated File: $varsFile : $USER on $(date)\n\n"

exit 0
