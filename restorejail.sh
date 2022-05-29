#!/bin/bash

#Start of restore script that bases off of any inventory jobs saved to get Glacier IDs (was relying off of backup logs but those get cleared on system update)

HEIGHT=15
WIDTH=50
CHOICE_HEIGHT=10
BACKTITLE="Restore Script"

#Defining conf file and setting variables from it
conf=/usr/local/etc/backup-script/back.conf

if [[ $(test -e $conf;echo $?) -ne 0 ]]
    then
	prinf "Configuration file does not exist!\nRun init script to create config file"
	exit 1
else
	source $conf
fi

c=1
curjaillist=$(jls | grep -v JID | awk '{print $2}')
for j in $curjaillist
    do
	curjailarray+=($c)
	curjailarray+=(" $j ")
	c=$(($c+1))
done

#Moving script to new inventory job availability checking
#relying on backup.log is not a good idea since it could get rolled over and thats just more work
inv=$(find $back_loc -name 'inv*.json' -mtime -30d |sed 's:.*/::')

if [[ (-z $inv) ]]
    then
	dialog --clear --backtitle "$BACKTITLE" --title "Local restore" --msgbox "There is no recent inventory job. Defaulting to local restore." $HEIGHT $WIDTH 2>&1 >/dev/tty
	jaillist=$(ls $back_loc | grep gz | sed 's/\@.*//' |sort -u)
	else
	#Using inventory job to generate list of archives
	archives=$(cat $back_loc/$inv | jq -r ".ArchiveList| .[]| .ArchiveId,.CreationDate,.ArchiveDescription" | paste - - -)
	#Using recent inventory job to generate available jails
	jaillist=$(cat $back_loc/$inv | jq -r ".ArchiveList| .[]| .ArchiveDescription" | cut -d/ -f4 | sort | uniq | grep -v "jails\|^@")
fi

if [[ $(zfs list -Ho name | grep -q tempmount ;echo $?) -eq 0 ]]
	then
		tempyesno=$(dialog --clear --backtitle "$BACKTITLE" --title "Temp mount found" --yesno "Do you want to remove it?" $HEIGHT $WIDTH 2>&1 >/dev/tty; echo $?)
		if [[ $tempyesno -eq 0 ]]
			then
				zfs destroy -r $(zfs list -Ho name | grep tempmount)
				continueyesno=$(dialog --clear --backtitle "$BACKTITLE" --title "Temp mount" --yesno "The temporary mount has been removed. Continue script?" $HEIGHT $WIDTH 2>&1 >/dev/tty ;echo $?)
				if [[ $continueyesno -eq 1 ]]
					then
						exit 0
				fi
		else 
				dialog --clear --backtitle "$BACKTITLE" --title "Temp mount" --msgbox "The script cannot be ran with a temporary mount still attached" $HEIGHT $WIDTH 2>&1 >/dev/tty
				exit 1
		fi
fi

c2=1
jailarray=()
for j in $jaillist
    do
	jailarray+=($c2)
	jailarray+=(" $j ")
	c2=$(($c2+1))
done

function restoreaction {

	RESTOREOPT=(	1 "Replace Jail"
		2 "New Jail"
		3 "Mount Temporarily")

	restorechoice=$(dialog --clear --backtitle "$BACKTITLE" --title "Select how to restore jail" --menu "Select:" $HEIGHT $WIDTH $CHOICE_HEIGHT "${RESTOREOPT[@]}" 2>&1 >/dev/tty)
	if [[ $restorechoice -eq 1 ]]
		then
		jailchoice=$(dialog --clear --backtitle "$BACKTITLE" --title "Select Jail to replace with $jail backup" --menu "Select:" $HEIGHT $WIDTH $CHOICE_HEIGHT "${curjailarray[@]}" 2>&1 >/dev/tty)
		curjail=$(echo $curjaillist |cut -d " " -f$jailchoice)
		iocage stop $curjail
		zfs destroy $(jpath $curjail)
		gzip -d -c $1 | pv | zfs recv $(jpath $curjail)
		iocage start $curjail
		echo "Jail backup restored to $curjail location"
		exit 0
	elif [[ $restorechoice -eq 2 ]]
		then
		newjailname=$(dialog --clear --backtitle "$BACKTITLE" --title "Enter new jail name:" --inputbox $HEIGHT $WIDTH 2>&1 >/dev/tty)
		newjailip=$(dialog --clear --backtitle "$BACKTITLE" --title "Enter new jail IP addr:" --inputbox $HEIGHT $WIDTH 2>&1 >/dev/tty)
		defroute=$(dialog --clear --backtitle "$BACKTITLE" --title "Enter default route IPv4" --inputbox $HEIGHT $WIDTH 2>&1 >/dev/tty)
		vnetyesno=$(dialog --clear --backtitle "$BACKTITLE" --title "Should the jail have vnet?" --yesno "" $HEIGHT $WIDTH 2>&1 >/dev/tty; echo $?)
		if [[ $vnetyesno -eq 1 ]]
			then
				vnet="off"
		else
			vnet="on"
		fi
		iocage create -r LATEST -n $newjailname ip4_addr=$newjailip boot=on vnet=$vnet default_route=$defroute
		#Getting new jail zfs path to destroy and replace with backup
		newjailpath=$(jpath $newjailname)
		iocage stop $newjailname
		zfs destroy $newjailpath
		gzip -d -c $1 | pv | zfs recv $newjailpath
		iocage start $newjailname
		echo "Jail backup restored to $newjailname"
		exit 0
	elif [[ $restorechoice -eq 3 ]]
		then
		pc=1
		poollist=$(zpool list -Ho name | grep -v boot)
		if [[ (-z "$poollist") ]]
			then
				echo "There are no pools to mount to"
				exit 1
		fi
		poolarray=()
		for p in $poollist
			do
				poolarray+=($pc)
				poolarray+=($p)
				pc=$(($pc+1))
		done
		if [[ $pc -eq 1 ]]
			then
			pool=$(echo $poollist|cut -d" " -f1)
			gzip -cd $1 | pv | zfs recv $pool/tempmount@restore
			restore_loc=$(zfs list -Ho mountpoint $pool/tempmount)
			echo "Restored data temporarily mounted at $restore_loc Run script again once you would like to remove it"
			exit 0
		else
			poolselect=$(dialog --clear --backtitle "$BACKTITLE" --title "Select which pool to mount the backup" --menu "Select:" $HEIGHT $WIDTH $CHOICE_HEIGHT "${poolarray[@]}" 2>&1 >/dev/tty)
			pool=$(echo $poollist | cut -d" " -f$poolselect)
			gzip -cd $1 | pv | zfs recv $pool/tempmount@restore
			restore_loc=$(zfs list -Ho mountpoint $pool/tempmount)
			echo "Restored data temporarily mounted at $restore_loc Run script again once you would like to remove it"
			exit 0
		fi
	fi
}

if [[ $(test -e $back_loc/retrievaljob.txt ;echo $?) -eq 0 ]]
	then
	dialog --clear --backtitle "$BACKTITLE" --title "AWS Archive retrieval" --msgbox "Detected inventory retrieval jobid so starting from that" $HEIGHT $WIDTH 2>&1 >/dev/tty
	jobid=$(echo $back_loc/retrievaljob.txt)
	backjid=$(jid $backname)
	jobcomplete=$(jexec $backjid aws glacier describe-job --account-id - --vault-name $vaultname --job-id="$jobid" |jq -r .Completed)
	if [ $jobcomplete == "false" ]
		then
			echo "Inventory job not complete. Re-run when it is complete"
			exit 1
	elif [ $jobcomplete == "true" ]
		then
			out=$(jexec $backjid aws glacier get-job-output --account-id - --vault-name $vaultname --job-id="$jobid" $back_loc/AWSjobout.gz)
			restoreaction $back_loc/AWSjobout.gz
			exit 0
	fi		
fi

#Asking for what jail to restore
jailchoice=$(dialog --clear --backtitle "$BACKTITLE" --title "Select Jail to restore" --menu "Select:" $HEIGHT $WIDTH $CHOICE_HEIGHT "${jailarray[@]}" 2>&1 >/dev/tty)

jail=$(echo $jaillist | cut -d " " -f$jailchoice)

datechoice=$(dialog --clear --backtitle "$BACKTITLE" --title "Enter date to restore" --inputbox "ex: 20190215 or last or locallist" $HEIGHT $WIDTH 2>&1 >/dev/tty)
if [ "$datechoice" == "last" ]
	then
		dateconvert=$(date -j -v-1d +%Y-%m-%d)
elif [ "$datechoice" == "list"]
	then
		datec=1
		datearray=()
		datelist=$(ls $back_loc/*.gz | grep $jail | sed 's/.*\@//' | sed 's/.gz//')
		for date in $datelist
			do
				datearray+=($datec)
				datearray+=( $date )
				datec=$(($datec+1))
		done
		datechoice=$(dialog --clear --backtitle "$BACKTITLE" --title "Select date from local" --menu "Select:" $HEIGHT $WIDTH $CHOICE_HEIGHT "${datearray[@]}" 2>&1 >/dev/tty)
else
	dateconvert=$(date -j -f "%Y%m%d" $datechoice "+%Y-%m-%d")
fi
# echo $dateconvert
localchoice=1
localpath=$(if [[ $(test -f $back_loc/$jail@$datechoice.gz ;echo $?) -eq 0 ]];then echo $back_loc/$jail@$datechoice.gz;else echo -n;fi)
if [[ (-z "$localpath") ]]
	then
	dialog --clear --backtitle "$BACKTITLE" --title "Local option" --msgbox "There is no local copy of the file" $HEIGHT $WIDTH 2>&1 >/dev/tty
else
	if [[ (-z $inv) ]]
		then
		localchoice=0
	else
		localchoice=$(dialog --clear --backtitle "$BACKTITLE" --title "Local restore choice" --yesno "There is a local copy, would you like to use that?" $HEIGHT $WIDTH 2>&1 >/dev/tty ;echo $?)
	fi
fi
if [[ $localchoice -eq 1 ]]
	then
	archiveId=$(cat $archives | grep $jail | grep "$dateconvert" | cut -f1)
	backjid=$(jid $backname)
	startjob=$(jexec $backjid aws glacier initiate-job --account-id - --vault-name $vaultname --job-parameters "{\"Type\": \"archive-retrieval\", \"ArchiveId\":\"$archiveId\"}"| jq -r .jobId)
	echo $startjob > $back_loc/retrievaljob.txt
	dialog --clear --backtitle "$BACKTITLE" --title "Archive Retrieval" --msgbox "The archive retrieval has started so re-run this script when notified of the job completion" $HEIGHT $WIDTH 2>&1 >/dev/tty
	exit 0
else
	restoreaction $localpath
	exit 0
fi
	