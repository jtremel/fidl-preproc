#!/bin/bash -ue
#
#---------------------------------------------------------------#
# plot_movt.sh
#
# Version 1.0.0
# 05.13.2011
#
# Josh Tremel
# (tremeljosh@gmail.com)
# University of Pittsburgh 
#---------------------------------------------------------------#
#
#   #-----------------------------------------------------------#
#   # Based on: see_movement.pl
#   # which has this header:
#   #   see_movement.pl = display movement data for bold runs
#   #   by J. R. Gray, Jan. 2000, CCP lab at Wash. U.
#   #   bug reports and comments welcome
#   #      (jgray@artsci.wustl.edu)
#   #-----------------------------------------------------------#

program=$0

# Number of required arguments
ARGS=1

# Check for correct number of arguments
if [ $# -ne $ARGS ]; then
	echo -e "USAGE:\t plot_movt <subject_id>"
	echo -e ""
	echo -e "\t Graphs movement data from the fidl preprocessing "
	echo -e "\t script using gnuplot. <Subject_id> should be the "
	echo -e "\t directory name, in which should be a folder called"
	echo -e "\t movement, containing the data to be plotted. This "
	echo -e "\t command should be run from the parent dir where the"
	echo -e "\t <subject_id> directory is located."
	exit 1
fi	

# Grab argument
subid=$1

# path to gnuplot
gnuplot=/usr/local/pkg/gnuplot-4.4.3/bin/gnuplot

# Set file extension from cmd opts.
#+ NOTE: for future, add option for plotting .dat (default), .ddat, and
#+ .rdat files
extension="dat"

# Set working directory
studypath=`pwd`
inpath=$studypath/$subid

# Set username
user=`whoami`

# Check for data file (eventually will be output from preproc.sh to QA dir)
# Create data file if it doesn't exist.
# 	make QA dir, grab files from movt dir, make data files to plot
if [ ! -d $inpath/QA ]; then
	mkdir $inpath/QA
	datafileExists=false
elif [ -d $inpath/QA ]; then
	if [ -e $inpath/QA/*_movt_all_runs.${extension}.data ]; then
		datafile=`find $inpath/QA/*_movt_all_runs.${extension}.data -type f`
		summaryfile=`find $inpath/QA/*_movt_all_runs.${extension}.summary -type f`
		datafileExists=true
	else
		datafileExists=false
	fi
fi

# Check for movement dir and grab files
while [ $datafileExists == false ]; do
	if [ -d $inpath/movement ]; then

	pushd $inpath/movement || { echo "movement dir not found, exiting..."; exit 1; }
	
		echo "Processing movement files..."
	
		# trim down subj ID
		subid=`basename $subid`
		# Count files
		nfiles=`find ${subid}_func*_*xr3d.${extension} -type f | wc -l`

		# Check for old "b1, b2, ..., bn" file format and fix
		bfiles=`find ${subid}_b?_*_xr3d.${extension} -type f 2>/dev/null | wc -l`
		if [ $bfiles -gt 0 ]; then
			for ((ibfiles=1; ibfiles<=${#nbfiles[@]}; ibfiles++)); do
				# Pad to 2 digits:
				ibfiles=`printf %02d $ibfiles`
				# Move to new file name
				mv ${subid}_b${ibfiles}_faln_dbnd_xr3d.${extension} ${subid}_func${ibfiles}_faln_dbnd_xr3d.${extension}
			done
			# These aren't needed anymore; clear from memory:
			unset ibfiles
		fi

		# Check for non-sortable files, if not, pad filenames to two-digits
		sfiles=`find ${subid}_func?_faln_dbnd_xr3d.${extension} -type f 2>/dev/null | wc -l`
		if [ $sfiles -gt 0 ]; then
			for ((ifiles=1; ifiles<=sfiles; ifiles++)); do
				mv ${subid}_func${ifiles}_faln_dbnd_xr3d.${extension} ${subid}_func0${ifiles}_faln_dbnd_xr3d.${extension}
			done
		fi
		files=(`find ${subid}_func??_*_xr3d.${extension} -type f`)

		# Echo file list to prompt
		echo "$nfiles files found:"
		find ${subid}_func??_*_xr3d.${extension} -type f | xargs -i echo -e "\t{}"
	else 
		# Exit if movement directory is not found for subject
		echo "Movement directory not found in: "
		echo "$program: $studypath/$subid/"
		exit 1
	fi

	# Concatenate files, output data file, summary stats
		# data file
		touch $inpath/QA/${subid}_movt_all_runs.${extension}.data
		datafile=$inpath/QA/${subid}_movt_all_runs.${extension}.data
		# Headings:
		echo "#TR    frame    dx(mm)    dy(mm)    dz(mm)    X(deg)    Y(deg)    Z(deg)     scale" >> $datafile
		# Put all data into file (-v to not print comment lines), and number lines
		grep -h -v "#" ${files[*]} | cat -n >> $datafile

		# summary stats file (not really being used for anything at the moment...)
		touch $inpath/QA/${subid}_movt_all_runs.${extension}.summary
		summaryfile=$inpath/QA/${subid}_movt_all_runs.${extension}.summary
		# Print everything that is a comment line (i.e., no data):
		grep -h "#" ${files[*]} >> $summaryfile

	popd	# pop to starting dir

	datafileExists=true	#we now have a datafile, exit block
done

pushd $inpath/QA/ >/dev/null

#Assemble graphing params from datafile
runStartTR=(`grep " 1 " $datafile | awk '{print $1}'`)	# grab lines containing first acq of each run
runStartBlank=(${runStartTR[*]}) 			# copy to a new, second array
# This is for axis labels ("label", placement on x axis, "label2", placement2, etc.):
for ((index=0; index<${#runStartTR[@]}; index++)); do
	let i=$index+1
	if (( $i < ${#runStartTR[@]} )); then
		# set labels
		runStartTR[index]=`printf "\""${runStartBlank[index]}"\" "${runStartBlank[index]}", "`
	elif (( $i == ${#runStartTR[@]} )); then
		# last one doesn't need the comma+space after it
		runStartTR[index]=`printf "\""${runStartBlank[index]}"\" "${runStartBlank[index]}`
	else
		echo "Something screwed up..."
		exit 1
	fi
	unset i
done

# remove any old temp.data files
if [ -e temp.data ]; then
	/bin/rm temp.data
fi
# make a new one for here
	touch temp.data
	# Get rid of header row so gnuplot can read it more easily
	awk 'FNR>1' $datafile >> temp.data

# compute max, min, mean for each movement domain using some neat awk cmds (output array order is [mean min max])
dxstats=(`awk -v col=3 '{if(min==""){min=max=$col}; if($col>max) {max=$col}; if($col<min) {min=$col}; total+=$col; count+=1} END {print total/count, min, max}' temp.data`)
dystats=(`awk -v col=4 '{if(min==""){min=max=$col}; if($col>max) {max=$col}; if($col<min) {min=$col}; total+=$col; count+=1} END {print total/count, min, max}' temp.data`)
dzstats=(`awk -v col=5 '{if(min==""){min=max=$col}; if($col>max) {max=$col}; if($col<min) {min=$col}; total+=$col; count+=1} END {print total/count, min, max}' temp.data`)
rxstats=(`awk -v col=6 '{if(min==""){min=max=$col}; if($col>max) {max=$col}; if($col<min) {min=$col}; total+=$col; count+=1} END {print total/count, min, max}' temp.data`)
rystats=(`awk -v col=7 '{if(min==""){min=max=$col}; if($col>max) {max=$col}; if($col<min) {min=$col}; total+=$col; count+=1} END {print total/count, min, max}' temp.data`)
rzstats=(`awk -v col=8 '{if(min==""){min=max=$col}; if($col>max) {max=$col}; if($col<min) {min=$col}; total+=$col; count+=1} END {print total/count, min, max}' temp.data`)

# find global min and max values to set y ranges on plot
/bin/rm temp.data
# Grab last acq # for maximum x-axis range
xmax=`cat $datafile | tail -1 | awk '{print $1}'`

### find lowest min value across the 6 domains
# start somewhere logical
ymin=${dxstats[1]}
# array of all 6 minima:
mins=(${dxstats[1]} ${dystats[1]} ${dzstats[1]} ${rxstats[1]} ${rystats[1]} ${rzstats[1]})
# loop through and find the lowest for the y-axis min range
for domain in `echo ${mins[*]}`; do
	# pipe comparison to bc so we can actually test the values (outputs 1 if true)
	mintest=$( echo "scale=3; $ymin > $domain " | bc)
	if [ $mintest -eq 1 ]; then
		# if true, this is the minimum
		ymin=$domain
	fi
	unset mintest					
done
unset domain
unset mins
# Round value upward to nearest integer
ymin=`echo $ymin | cut -d "." -f 1`; ymin=$((ymin-1))

# find highest max value across the 6 domains (same procedure as ymin above)
ymax=${dxstats[2]}
maxs=(${dxstats[2]} ${dystats[2]} ${dzstats[2]} ${rxstats[2]} ${rystats[2]} ${rzstats[2]})
for domain in `echo ${maxs[*]}`; do
	maxtest=$( echo "scale=3; $ymax < $domain " | bc)
	if [ $maxtest -eq 1 ]; then
		ymax=$domain
	fi
	unset maxtest
done
unset domain
unset maxs
ymax=`echo $ymax | cut -d "." -f 1`; ymax=$((ymax+1)) #Round value upward to nearest integer

# if values don't go beyond 6 mm/deg in any domain, set y bounds to +/-6
#+	otherwise set to ymin/ymax
if (( $ymin > -6 )); then ymin=-6; fi
if (( $ymax < 6 )); then ymax=6; fi

#Clean up datafile name for plot title
datafileBase=`basename $datafile`


# Also plot mean somewhere in the here doc.
# What about rms and sd?


# gnuplot script (-persist keeps graph open after here block is done):
$gnuplot -persist <<movtplot

	set key outside
	set xtics (${runStartTR[*]})
	set grid
	set grid noytics
	set yrange [ $ymin : $ymax ]
	set xrange [ 0 : $xmax ]
	set title "$datafileBase" font "Helvetica,20"
	set xlabel "Time (Acquisition #)" font "Helvetica,20"
	set ylabel "Displacement (mm) or Rotation (degrees)" font "Helvetica,20"
	
	set xzeroaxis
	
	plot "$datafile" \
	using 3 with lines lt 1 lw 2 linecolor rgb "black" title "dx (mm)", \
	'' using 4 with lines lt 1 lw 2 linecolor rgb "red" title "dy (mm)", \
	'' using 5 with lines lt 1 lw 2 linecolor rgb "green" title "dz (mm)", \
	'' using 6 with lines lt 1 lw 2 linecolor rgb "blue" title "X (deg)", \
	'' using 7 with lines lt 1 lw 2 linecolor rgb "yellow" title "Y (deg)", \
	'' using 8 with lines lt 1 lw 2 linecolor rgb "brown" title "Z (deg)"
movtplot
# end here block

# Pop back to start dir
popd >/dev/null

exit 0
