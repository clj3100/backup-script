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
	backname=$(dialog --clear --backtitle "$BACKTITLE" --title "Name for backup jail" --inputbox "What name for the backup jail?" $HEIGHT $WIDTH 2>&1 >/dev/tty)
	ip=$(dialog --clear --backtitle "$BACKTITLE" --title "IP for backup jail" --inputbox "What IP address for backup jail?" $HEIGHT $WIDTH 2>&1 >/dev/tty)
	defroute=$(dialog --clear --backtitle "$BACKTITLE" --title "Default route for backup jail" --inputbox "What is the defalt route for the backup jail?" $HEIGHT $WIDTH 2>&1 >/dev/tty)
	if [[ $checkiocage -eq 0 ]]
	    then
		iocage create -r LATEST -n $backname ip4_addr=$ip boot=on vnet=on defaultrouter=$defroute
		sed -e "s/^back_jail=.*/back_jail=$name" -i $localetc/back.conf
		backjid=$(jid $backname)
		#Installing nessecary packages in the jail
		jexec $backjid setenv ASSUME_ALWAYS_YES yes ; pkg ; pkg install awscli py38-pip
		jexec $backjid pip install TreeHash
		awsid=$(dialog --clear --backtitle "$BACKTITLE" --title "AWS CLI config" --inputbox "Enter your aws access key" $HEIGHT $WIDTH 2>&1 >/dev/tty)
		awssecret=$(dialog --clear --backtitle "$BACKTITLE" --title "AWS CLI config" --inputbox "Enter your aws secret access key" $HEIGHT $IWDTH 2>&1 >/dev/tty)
		regionarray=()
		regionlist=$(jexec $backjid aws ec2 describe-regions | jq -r ".|.[]|.[] .RegionName")
		count=1
		for reg in $regionlist
		    do
			regionarray+=($count)
			regionarray+=("$reg")
			count=$(($count+1))
		done		
		regionchoice=$(dialog --clear --backtitle "$BACKTITLE" --title "Select default region" --menu "Options:" $HEIGHT $WIDTH $CHOICE_HEIGHT "${regionarray[@]}" 2>&1 >/dev/tty)
		region=$(($regionchoice*2-1))
		jexec $backjid mkdir /root/.aws ;printf "[default]\naws_access_key_id = $awsid\naws_secret_access_key = $awssecret" >/root/.aws/credentials
		jexec $backjid printf "[default]\nregion = $region" > /root/.aws/config
		jexec $backjid mkdir /backup
		vaultname=$(dialog --clear --backtitle "$BACKTITLE" --title "S3 Glacier vault name" --inputbox "What is the name of the Glacier vault? (If it does not exist this script will create it)" $HEIGHT $WIDTH 2>&1 >/dev/tty)
		jexec $backjid aws glacier create-vault --account-id - --vault-name $vaultname
		sed -e "s/^vaultname=.*/vaultname=\"$vaultname\"" -i $localetc/back.conf
	elif [[ $checkwarden -eq 0 ]]
	    then
		#Need to create the warden jail creation section
		echo "There is no iocage installed. This backup script only supports iocage"
		exit 1 
	fi
else
	dialog --clear --backtitle "$BACKTITLE" --title "Info for backup jail" --infobox "The backup jail needs to have awscll installed as well as the treehash command for hash generation" $HEIGHT $WIDTH 2>&1 >/dev/tty
	exit 0
fi
