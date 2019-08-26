#!/bin/bash

#Script to prune current backups from Glacier as the storage costs to get a little high after 2 or so TB

vault_name=backup-cjonesflix
backup_jail=Backup

#Defining function for getting the jail ID
function jid {

jls | grep "$1" | awk '{print $1}'

}

#Generating the days to keep so everything else is removed

#Array init
dates=()

#Loop gets the last day of each month and saves to array
for m in $(seq 1 12);
    do
	dates+=($(date -j -v+1m -v-1d -f %m.%d $m.1 +%m/%d))
done


