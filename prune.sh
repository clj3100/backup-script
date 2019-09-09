#!/bin/bash

#Script to prune current backups from Glacier as the storage costs get a little high after 2 or so TB
#Automatically run script using jobwatch to call the script back when inventory job is done

#Its like cronjob runs script
#Script checks for recent inventory job just incase there was one manually run from the restore script (just in case)
#If inventory is older than 30 days then call new inventory job and wait for it to finish

vault=backup-cjonesflix
backup_jail=Backup
backup_loc=/mnt/Backup/jails

#Defining function for getting the jail ID
function jid {

jls | grep "$1" | awk '{print $1}'

}

backjid=$(jid $backup_jail)

#Generating the days to keep so everything else is removed

#Array init
dates=()

#Loop gets the last day of each month and saves to array
for m in $(seq 1 12)
    do
	dates+=($(date -j -v+1m -v-1d -f %m.%d $m.1 +%m/%d))
done

#Checking for any inventory files that are newer than 30 days

inv=$(find $backup_loc -name 'inv*.json' -mtime -30d)

#Testing if above variable is empty and if it is then starting a job for new inventory
if [[ (-z "$inv") ]]
    then
	invjob=$(jexec $backjid aws glacier initiate-job --account-id - --vault-name backup-cjonesflix --job-parameters '{"Type": "inventory-retrieval"}' | jq -r .JobId)
	#Watching for above job completion then continuing script
	while true
	    do
	        jobs=$(jexec $backjid aws glacier list-jobs --account-id - --vault-name $vault)
	        status=$(echo "$jobs" | jq -r ".JobList|.[]|if .JobId==\"$jobid\" then .Completed else empty end")
	        if [ "$status" == "true" ]
	            then
	                #echo JOB DONE
	                break
	        else
	                #echo JOB NOT DONE
	                sleep 900
	        fi
	done
fi
#This means the inventory is recent so it needs to continue the prune

#asking for inventory job but different idea for script makes this not used
#if [[ $(test -e $backup_loc/inventory.txt) -eq 1 ]]
#    then
#	invjob=$(dialog --clear --backtitle "$BACKTITLE" --title "Inventory Job" --yesno "There is no stored inventory file. Do you want to start the inventory retrieval job?" $HEIGHT $WIDTH 2>&1 >/dev/tty ;echo $?)
#fi
