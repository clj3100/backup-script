#!/bin/bash

back_loc=/mnt/Backup/jails
jail_back_loc=/backup
jail=$1
back_jail="Backup"
vaultname="backup-cjonesflix"
backup_log="/var/log/backup.log"

#Defining function for getting the jail ID
function jid {

jls | grep "$1" | awk '{print $1}'

}

#Defining a function to get the zfs path of the jail
function jpath {

zfs list | grep "$1" | grep /root |awk '{print $1}'

}

jailpath=$(jpath $jail)
snapname="$jailpath@backup_$jail"
filename="$jail@$(date +%Y%m%d).gz"

#echo $snapname
#echo $filename

#Adding line to backup log
echo $(date '+%b %d %H:%M:%S') $(hostname -s) backup: Starting backup of $jail #>> $backup_log

#Creating the snapshot
#zfs snapshot $snapname

#Copying snapshot to file
#zfs send $snapname | gzip > $back_loc/$filename

#Getting size of file
#filesize=$(stat $back_loc/$filename |cut -d" " -f8)

if [[ $filesize -gt 3500000000 ]]
    then
	#Multipart Upload TEMP FOR NOW
	echo -n
else
	#Uploading to Glacier
	#$result=$(jexec $(jid $back_jail) aws glacier upload-archive --account-id - --vault-name $vaultname --body $jail_back_loc/$filename --archive-description $jailpath)
	echo -n
fi

archiveId=$(echo $result | jq -r .archiveId)

echo $(date '+%b %d %H:%M:%S') $(hostname -s) backup: Finished backup of $jail as $archiveId #>> $backup_log
