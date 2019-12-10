#!/bin/bash

#Script to prune current backups from Glacier as the storage costs get a little high after 2 or so TB
#Automatically run script using jobwatch to call the script back when inventory job is done

#Its like cronjob runs script
#Script checks for recent inventory job just incase there was one manually run from the restore script (just in case)
#If inventory is older than 30 days then call new inventory job and wait for it to finish

#Defining conf file and setting variables from it
conf=/root/back.conf

if [[ $(test -e $conf;echo $?) -ne 0 ]]
    then
        printf "Configuration file does not exist!\nRun init script to create config file"
        exit 1
else
        source $conf
fi


function inarray {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

backjid=$(jid $back_jail)

#Generating the days to keep so everything else is removed

#Array init
dates=()

#Loop gets the last day of each month and saves to array
for m in $(seq 1 12)
    do
	dates+=($(date -j -v+1m -v-1d -f %m.%d $m.1 +%m/%d))
done

#Checking for any inventory files that are newer than 30 days

inv=$(find $back_loc -name 'inv*.json' -mtime -30d |sed 's:.*/::')

#Testing if above variable is empty and if it is then starting a job for new inventory
if [[ (-z "$inv") ]]
    then
	invjob=$(jexec $backjid aws glacier initiate-job --account-id - --vault-name $vaultname --job-parameters '{"Type": "inventory-retrieval"}' | jq -r .JobId)
	#Watching for above job completion then continuing script
	while true
	    do
	        jobs=$(jexec $backjid aws glacier list-jobs --account-id - --vault-name $vaultname)
	        status=$(echo "$jobs" | jq --args id "$invjob" -r '.JobList|.[]|if .JobId=="$id" then .Completed else empty end')
	        if [ "$status" == "true" ]
	            then
	                #echo JOB DONE
			#saving completed job to file
			inv="inv$(date +%m%d%y).json"
			out=$(jexec $backjid aws glacier get-job-output --account-id - --vault-name $vaultname --job-id="$invjob" $jail_back_loc/$inv)
	                break
	        else
	                #echo JOB NOT DONE
	                sleep 900
	        fi
	done
fi
#This means the inventory is recent so it needs to continue the prune

#Generating a parsable list of all archives
archives=$(cat $back_loc/$inv | jq -r ".ArchiveList| .[]| .ArchiveId,.CreationDate,.ArchiveDescription" | paste - - -)

#setting newline to for delimiter
IFS=$'\n'
for i in $archives
    do
	adate=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" $(echo $i | cut -f2) "+%m/%d")
	adatesec=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" $(echo $i | cut -f2) "+%s")
	cursec=$(date -v -90d +%s)
	aid=$(echo $i | cut -f1)
	if [[ $(inarray "$adate" "${dates[@]}" ;echo $?) -eq 1 ]]
	    then
		#Backup is not in the last day of any month
		if [[ "$adatesec" -lt "$cursec" ]]
		    then
			#Here it is not the last day of the month and not within the 90 day period
			jexec $backjid aws glacier delete-archive --account-id - --vault-name $vaultname --archive-id="$aid"
			#echo $i
		else
			echo -n
		fi
	else
		echo -n
	fi
done

