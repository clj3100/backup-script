#!/bin/bash

#Start of restore script that bases off of the backup logs to get archiveIds

HEIGHT=15
WIDTH=40
CHOICE_HEIGHT=10
BACKTITLE="Restore Script"

#Defining conf file and setting variables from it
conf=/usr/local/etc/back.conf
source $conf

c=1
curjaillist=$(jls | grep -v JID | awk '{print $2}')
for j in $curjaillist
    do
	curjailarray+=($c)
	curjailarray+=(" $j ")
	c=$(($c+1))
done

RESTOREOPT=(	1 "Replace Jail"
		2 "New Jail"
		3 "Mount Temporarily")

#Moving script to new inventory job availability checking
#relying on backup.log is not a good idea since it could get rolled over and thats just more work
inv=$(find $back_loc -name 'inv*.json' -mtime -30d |sed 's:.*/::')

archives=$(cat $back_loc/$inv | jq -r ".ArchiveList| .[]| .ArchiveId,.CreationDate,.ArchiveDescription" | paste - - -)

if [[ (-z $inv) ]]
    then
	echo "Please run the prune script in a detached console to get a recent inventory job"
	exit 1
fi

#Using recent inventory job to generate available jails
jaillist=$(cat $back_loc/$inv | jq -r ".ArchiveList| .[]| .ArchiveDescription" | cut -d/ -f4 | sort | uniq | grep -v "jails\|^@")


#Asking for what jail to restore
jailchoice=$(dialog --clear --backtitle "$BACKTITLE" --title "Select Jail to restore" --menu "Select:" $HEIGHT $WIDTH $CHOICE_HEIGHT "${jailarray[@]}" 2>&1 >/dev/tty)

jail=$(echo $jaillist | cut -d " " -f$jailchoice)

datechoice=$(dialog --clear --backtitle "$BACKTITLE" --title "Enter date for jail backup to restore" --inputbox "example: 20190215" $HEIGHT $WIDTH 2>&1 >/dev/tty)
dateconvert=$(date -j -f "%Y%m%d" $datechoice "+%b %d")
echo $dateconvert
localchoice=1
localpath=$(if [[ $(test -f $back_loc/$jail@$datechoice.gz ;echo $?) -eq 0 ]];then echo $back_loc/$jail@$datechoice.gz;else echo -n;fi)
if [[ (-z "$localpath") ]]
    then
	dialog --clear --backtitle "$BACKTITLE" --title "Local option" --infobox "There is no local copy of the file" $HEIGHT $WIDTH 2>&1 >/dev/tty
else
	localchoice=$(dialog --clear --backtitle "$BACKTITLE" --title "Local restore choice" --yesno "There is a local copy, would you like to use that?" $HEIGHT $WIDTH 2>&1 >/dev/tty ;echo $?)
fi
if [[ $localchoice -eq 1 ]]
    then
	archiveId=$(grep saved /var/log/backup.log | grep $jail | grep "$dateconvert" | cut -d" " -f13)
	if [[ (-z "$archiveid") ]]
	    then
		inventorychoice=$(dialog --clear --backtitle "$BACKTITLE" --title "AWS Inventory Job" --defaultno --yesno "There is no backup with that date in logs. Would you like to run an AWS Inventory retrieval?" $HEIGHT $WIDTH 2>&1 >/dev/tty ;echo $?)
		if [[ $inventorychoice -eq 0 ]]
		    then
			startjob=$(jexec $(jid $back_jail) aws glacier initiate-job --account-id --vault-name $vaultname --job-parameters '{"Type": "inventory-retrieval"}')
			jobId=$(echo $startjob | jq -r .jobId)
			echo "$jobId" > $back_loc/inventoryjob.txt
		else
			echo "If you dont pick an option then there is no use for the script"
			exit 1
		fi
	else
		echo $archiveId
		exit 0
	fi
	
else
	restorechoice=$(dialog --clear --backtitle "$BACKTITLE" --title "Select how to restore jail" --menu "Select:" $HEIGHT $WIDTH $CHOICE_HEIGHT "${RESTOREOPT[@]}" 2>&1 >/dev/tty)
	if [[ $restorechoice -eq 1 ]]
	    then
		jailchoice=$(dialog --clear --backtitle "$BACKTITLE" --title "Select Jail to replace with $jail backup" --menu "Select:" $HEIGHT $WIDTH $CHOICE_HEIGHT "${curjailarray[@]}" 2>&1 >/dev/tty)
	elif [[ $restorechoice -eq 2 ]]
	    then
		newjailname=$(dialog --clear --backtitle "$BACKTITLE" --title "Enter new jail name:" --inputbox $HEIGHT $WIDTH 2>&1 >/dev/tty)
		newjailip=$(dialog --clear --backtitle "$BACKTITLE" --title "Enter new jail IP addr:" --inputbox $HEIGHT $WIDTH 2>&1 >/dev/tty)
		iocage create -r LATEST -n $newjailname ip4_addr=$newjailip boot=on vnet=on default_route=10.10.0.1
		#Getting new jail zfs path to destroy and replace with backup
		newjailpath=$(jpath $newjailname)
		zfs destroy $newjailpath
		#Placeholder for the extracting of local jail backup from $localpath

	elif [[ $restorechoice -eq 3 ]]
	    then
		#Section for temporary mount jail 
		#Placeholder for extracting to temp zfa location
		echo "After restore section"
		exit 0
	fi
fi