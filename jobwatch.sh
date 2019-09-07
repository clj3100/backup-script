#!/bin/bash

#Script called by prune to watch for completed JobId

jobid="$1"
backupjail=Backup
vault=backup-cjonesflix

#Defining function for getting the jail ID
function jid {

jls | grep "$1" | awk '{print $1}'

}

backupjid=$(jid $backupjail)

while true
    do
	jobs=$(jexec $backupjid aws glacier list-jobs --account-id - --vault-name $vault)
	status=$(echo "$jobs" | jq -r ".JobList|.[]|if .JobId==\"$jobid\" then .Completed else empty end")
	if [ "$status" == "true" ]
	    then
		#echo JOB DONE
		exit 0
	else
		#echo JOB NOT DONE
		sleep 900
	fi
done
