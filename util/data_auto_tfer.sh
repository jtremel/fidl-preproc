#!/bin/bash
#
#----------------------------------------------------------------
#  nic_auto_tfer.sh
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
# Revision 1.1: jt (Current)
# 03.05.2013
#    Added variables for local target directory and remote server
#     options (user, IP, directory) for easier changing later.
#
# Revision 1.0: jt
# 11.09.2012
#
#----------------------------------------------------------------
# Program and User info
#----------------------------------------------------------------
COMMAND=$0
PROGRAM="nic_auto_tfer.sh"
VERSION=1.0
USER=$(whoami)
TIME=$(date '+%Y%b%d-%H%M%S')
LOGFILE="nic_auto_tfer_${TIME}.log"
#----------------------------------------------------------------
# Program Usage
#----------------------------------------------------------------
# Function to display program usage
usage() {
	cat << usageEOF
nic_auto_tfer.sh version $VERSION
  Usage: nic_auto_tfer.sh
  Description:
    Automatic rsync transfer from NIC to Calipso. Grabs any directories created
	within the last 24 hours on the NIC server (/home/wheeler/studies/) and 
	transfers them to Calipso:/data/data2/nic_transfer.

	This script is set to run at 5 AM every morning.

	NOTE: This requires a passwordless ssh login to the NIC server and runs
	under user jt.
usageEOF
	exit $1
}

# Check for arguments; call usage(), if not 0.
if [ $# != 0 ]; then
	usage 10 1>&2
fi

#---------------------------------------------------------------
# Settings
#---------------------------------------------------------------
# Local directory to transfer to
transferDir=/data/data2/nic_transfer
# Remote server IP
remoteIP=136.142.36.60
# Remote username
remoteUser=wheeler
# Remote data directory (should contain any scan directory you want to transfer)
remoteDir=/home/wheeler/studies/

#---------------------------------------------------------------
# Set up a new log
LOGFILE="$transferDir/log/${LOGFILE}"
touch ${LOGFILE}

echo "${PROGRAM} started on $( date )" >>${LOGFILE}
echo "" >>${LOGFILE}

# Make sure we have a working passwordless ssh to NIC
ssh -o 'PreferredAuthentications=publickey' ${remoteUser}@${remoteIP} "echo" >/dev/null
if [ $? != 0 ]; then
	printf "\nERROR: Passwordless SSH to NIC server is not enabled." >>${LOGFILE}
	printf "\nPlease set this up and try again.\n">>${LOGFILE}
	exit 2
fi

# Check if we have new dirs to transfer (new dirs in last 24 hours)
nNew=$(ssh ${remoteUser}@${remoteIP} "find ${remoteDir} -maxdepth 1 -mtime -1 -type d | awk 'FNR>1' | wc -l")

#----------------------------------------------------------------
# Transfer
#----------------------------------------------------------------
if [ $nNew -gt 0 ]; then
	echo "$nNew new scans to transfer..." >>${LOGFILE}
	echo "" >> ${LOGFILE}
	# Get list of directories in 'studies' dir modified in last 24 hours with find. Trim off top of list (root dir).
	for file in $(ssh ${remoteUser}@${remoteIP} "find ${remoteDir} -maxdepth 1 -mtime -1 -type d | awk 'FNR>1'"); do
	  echo ${file} >>${LOGFILE}
	  rsync -rlptyD --progress --partial --rsh="ssh -l ${remoteUser}" ${remoteIP}:${file} $transferDir >>${LOGFILE}
	done
	
	echo "" >>${LOGFILE}
	echo "Transfer Complete..." >> ${LOGFILE}
	echo "" >>${LOGFILE}
	echo "Changing permissions..." >>${LOGFILE}
	chmod -R 770 $transferDir/*
	if [ $? != 0 ]; then
		echo "ERROR: problem changing permissions..." >>${LOGFILE}
	fi
	chmod 640 $transferDir/log/*
	echo "" >>${LOGFILE}
	echo "Finished on $( date )" >>${LOGFILE}
	echo "" >>${LOGFILE}
else
	echo "No new files to transfer. Exiting..." 
	/bin/rm ${LOGFILE}
fi


exit 0
