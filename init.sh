#!/bin/bash

#Script to setup all of the related backup scripts

#Checking for iocage or warden to create backup jail
checkiocage=$(iocage list ;echo $?)
checkwarden=$(warden list ;echo $?)

HEIGHT=15
WIDTH=40
CHOICE_HEIGHT=10
BACKTITLE="Initialization Script"

localetc=/usr/local/etc

mkdir -p $localetc/git
git clone https://github.com/clj3100/backup-script $localetc/git
ln -s $localetc/git/backup-script/back.conf $localetc/back.conf
for file in $(find $localetc/git/backup-script -name '*.sh')
    do
	name=$(echo $file|sed 's/.sh//')
	ln -s $file /usr/local/sbin/$name
done

if [[ $(test -e $localetc/back.conf;echo $?) -eq 0 ]]
    then
	#Running source to the back file to load jid and jpath functions
	source $localetc/back.conf
fi

#Asking for backup jail creation
createbackjail=$(dialog --clear --backtitle "$BACKTITLE" --title "Create backup jail" --yesno "Do you want this script to create the backup jail?" $HEIGHT $WIDTH 2>&1 >/dev/tty ;echo $?)

if [[ $createbackjail -eq 0 ]]
    then
	ip=$(dialog --clear --backtitle "$BACKTITLE" --title "IP for backup jail" --inputbox "What IP address for backup jail?" $HEIGHT $WIDTH 2>&1 >/dev/tty)
	if [[ $checkiocage -eq 0 ]]
	    then
		iocage create -r LATEST -n Backup ip4_addr=$ip boot=on vnet=on
		backjid=$(jid Backup)
		#Need to run the command to install pkg in new jail cause recent new jails do not have it by default
		jexec $backjid pkg -y install awscli ruby25-gems 
		jexec $backjid gem install treehash
		awsid=$(dialog --clear --backtitle "$BACKTITLE" --title "AWS CLI config" --inputbox "Enter your aws access id" $HEIGHT $WIDTH 2>&1 >/dev/tty)
		awssecret=$(dialog --clear --backtitle "$BACKTITLE" --title "AWS CLI config" --inputbox "Enter your aws access secret" $HEIGHT $IWDTH 2>&1 >/dev/tty)
		
	elif [[ $checkwarden -eq 0 ]]
	    then
		#Need to create the warden jail creation section
		echo -n
	fi
else
	dialog --clear --backtitle "$BACKTITLE" --title "Info for backup jail" --infobox "The backup jail needs to have awscll installed as well as the treehash command for hash generation" $HEIGHT $WIDTH 2>&1 >/dev/tty
	exit 0
fi
