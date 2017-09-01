#!/bin/bash
#
#----------------------------------------------------------------
#  nic_transfer.sh
#  Transfer data from the NIC server under the wheeler account
#  via rsync.
#
#  Version 1.0
#  11.09.2012
#
#  Josh Tremel
#  (tremeljosh@gmail.com)
#  University of Pittsburgh
#----------------------------------------------------------------
# REVISION HISTORY:
#----------------------------------------------------------------
# Revision 1.0: JT (current)
# 11.09.2012
#

#----------------------------------------------------------------
# Program and User info
#----------------------------------------------------------------
COMMAND=$0
PROGRAM=nic_transfer.sh
VERSION=1.0
USER=$(whoami)

# Number of required arguments
ARGS=2

#----------------------------------------------------------------
# Program Usage
#----------------------------------------------------------------
# Function to display program usage
usage() {
	cat << usageEOF
nic_transfer.sh version $VERSION
  Usage: nic_transfer.sh <nic subj record number> <destination directory>
  Description:
    Easy rsync transfer from NIC to calipso

    <nic subj record number> Subject ID on the scan sheet from NIC. Should
	be the date and time of the scan (e.g., YYMMDDHHMMSS, 121108125356)
	
	<destination directory> Where you want to put your files. This will
	create directories and sub-directories if it does not exist. Full
	path is not necessary, but recommended to prevent errors.
	
	NOTE: You MUST have a passwordless ssh login to the NIC server for
	this to work!
usageEOF
	exit $1
}

# Check for correct number of arguments; call usage(), if wrong
if [ $# != $ARGS ]; then
	usage 10 1>&2
fi

# Grab args
subjID=$1
targetDir=$2

# Create target directory
if [ ! -d $targetdir ]; then mkdir -p $targetDir; fi
if [ $? != 0 ]; then
	printf "\nError creating target directory.\n"
	exit 1
fi

# Push into target directory
pushd $targetDir
if [ $? != 0 ]; then 
	printf "\nError finding target directory. Could not change to target directory.\n"
	exit 1
fi

# Make sure user has passwordless ssh to NIC
ssh -o 'PreferredAuthentications=publickey' wheeler@136.142.36.60 "echo" >/dev/null
if [ $? != 0 ]; then
	printf "\nPasswordless SSH to NIC server is not enabled."
	printf "\nPlease set this up and try again.\n"
	exit 2
fi

#----------------------------------------------------------------
# Begin transferring
#----------------------------------------------------------------
for file in $(ssh wheeler@136.142.36.60 "ls -1d /home/wheeler/studies/$subjID"); do
  echo ${file}
  rsync -rlptyD --progress --partial --rsh="ssh -l wheeler" 136.142.36.60:${file} ./
done

exit 0
