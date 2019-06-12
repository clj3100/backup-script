#!/bin/bash

#Start of restore script that bases off of the backup logs to get archiveIds

HEIGHT=15
WIDTH=40
CHOICE_HEIGHT=10
BACKTITLE="Restore Script"

back_loc=/mnt/Backup/jails

uselocal=0

c=1
jailarray=()
jaillist=$(grep saved /var/log/backup.log | cut -d" " -f10 | sort | uniq)
for j in $jaillist
    do
	jailarray+=($c)
	jailarray+=(" $j ")
	c=$(($c+1))
done

RESTOREOPT=(	1 "Replace Jail"
		2 "New Jail"
		3 "Mount Temporarily")

jailchoice=$(dialog --clear --backtitle "$BACKTITLE" --title "Select Jail to restore" --menu "Select:" $HEIGHT $WIDTH $CHOICE_HEIGHT "${jailarray[@]}" 2>&1 >/dev/tty)

jail=$(echo $jaillist | cut -d " " -f$jailchoice)


datechoice=$(dialog --clear --backtitle "$BACKTITLE" --title "Enter date for jail backup to restore" --inputbox "example: 20190215" $HEIGHT $WIDTH 2>&1 >/dev/tty)
dateconvert=$(date -j -f "%Y%m%d" $datechoice "+%b %d")
echo $dateconvert
localpath=$(if [[ $(test -f $back_loc/$jail@$datechoice.gz ;echo $?) -eq 0 ]];then echo $back_loc/$jail@$datechoice.gz;else echo -n;fi)
if [[ (-z "$localpath") ]]
    then
	read -r -p "The backup is local, would you like to use that? Y/N" localchoice
else
	echo -n
fi

if [[ "$localchoice" =~ ^([yY][eE][sS]|[yY])+$ ]]
    then
        uselocal=1
else
        echo -n
fi

if [[ $uselocal -eq 0 ]]
    then
	archiveId=$(grep saved /var/log/backup.log | grep $jail | grep "$dateconvert" | cut -d" " -f13)
	if [ (-z "$archiveid") ]
	    then
		echo "That backup date for that jail does not exist"
		exit 1
	else
		exit 0
	fi
	echo $archiveId
else
	
