#!/bin/bash
#
#----------------------------------------------------------------
#  fix_mprage_orientation.sh
#  Fixes the atlas transformed mprage so that it uses the correct
#  orientation and cuts to the axial plane.
#
#  Version 1.00
#  11.19.2013
#
#  Josh Tremel
#  (tremeljosh@gmail.com)
#  University of Pittsburgh
#
#----------------------------------------------------------------
# Program and User info
#----------------------------------------------------------------
COMMAND=$0
PROGRAM=preproc.sh
VERSION=1.00
USER=$(whoami)

# Number of required arguments
ARGS=1

#----------------------------------------------------------------
# Program Usage
#----------------------------------------------------------------
# Function to display program usage
usage() {
	cat << usageEOF
fix_mprage_orientation.sh v${VERSION}
  Usage: fix_mprage_orientation.sh <subject_id>
  Description:
    Fixes a preprocessing error where a sagittally-acquired
	mprage remained in sagittal orientation. This removes old 
	mprage 222 and 333 files and creates axial versions.

    <subject_id> is the name of the subject directory to fix. 

	Run this from the study directory.

usageEOF
	exit $1
}

# Check for correct number of arguments; call usage(), if wrong
if (( $# != $ARGS )); then
	usage 10 1>&2
fi

#----------------------------------------------------------------
subjId=$1
pushd ${subjId}/atlas >/dev/null

\rm ${subjId}_mprage*222*4dfp.*
\rm ${subjId}_mprage*333*4dfp.*

t4img_4dfp ${subjId}_mprage_to_711-2B_t4 ${subjId}_mprage ${subjId}_mprage_t88_222 -O222
t4img_4dfp ${subjId}_mprage_to_711-2B_t4 ${subjId}_mprage ${subjId}_mprage_t88_333 -O333

popd >/dev/null

exit 0
