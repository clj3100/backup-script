#!/bin/bash

#Defining conf file and setting variables from it
conf=/root/back.conf

if [[ $(test -e $conf;echo $?) -ne 0 ]]
    then
	prinf "Configuration file does not exist!\nRun init script to create config file"
	exit 1
else
	source $conf
fi

#If arguments are empty then show usage and exit
if [[ (-z $*) ]]
    then
	echo -e "Script to backup freebsd jails to a local directory and S3 Galcier\n Config file: $conf\nUsage: backup <jail>"
	exit 1
fi

#Defining a debug step by step function
function verify {

read -r -p "Continue? Y/N" yesno
if [[ "$yesno" =~ ^([yY][eE][sS]|[yY])+$ ]]
    then
	echo -n
else
	exit 1
fi
}

jail=$1
jailpath=$(jpath $jail)
snapname="$jailpath@backup_$jail"
filename="$jail@$(date +%Y%m%d).gz"

#Converting partsize to bytes
partsize=$( echo $partsize |sed -e 's/K/\*1024/g' -e 's/M/\*1048576/g' -e 's/G/\*1073741824/g' | bc)

#echo $snapname
#echo $filename

#Adding line to backup log
echo $(date '+%b %d %H:%M:%S') $(hostname -s) backup: Starting backup of jail $jail >> $backup_log

#Creating the snapshot
zfs snapshot $snapname

#Copying snapshot to file
zfs send $snapname | gzip > $back_loc/$filename

#Removing the snapshot as it shouldnt be taking incremental drive space
zfs destroy $snapname

#Getting size of file
filesize=$(stat -f %z $back_loc/$filename)

#Generating treehash
hash=$(jexec $(jid $back_jail) treehash "$jail_back_loc/$filename")

echo $hash > $hash_loc/$jail@$(date +%Y%m%d).hash

i=0
if [[ $filesize -gt 3500000000 ]]
    then
	#Multipart Upload
	#Initiating the upload job
	echo $(date '+%b %d %H:%M:%S') $(hostname -s) backup: Uploading to Glacier >> $backup_log
	init=$(jexec $(jid $back_jail) aws glacier initiate-multipart-upload --account-id - --vault-name $vaultname --part-size $partsize --archive-description $jailpath)
	uploadid=$(echo $init | jq -r .uploadId)
	#echo $uploadid
	#Making tempdir and splitting file
	tmppath=$(TMPDIR=$back_loc mktemp -d)
	tmpd=$(echo $tmppath | sed 's:.*/::')
	(cd $tmppath && split -a3 -b$partsize "$back_loc/$filename" part)
	filelist=$(ls $tmppath |sort)
	#echo $tmppath
	#Uploading parts
	for f in $filelist;
	    do
		if [[ $(stat -f %z $tmppath/$f) -lt $partsize ]]
		     then
			byteStart=$((i*partsize))
			byteEnd=$(($filesize-1))
			file=$(echo $f | sed 's:.*/::')
			checksum=$(jexec $(jid $back_jail) aws glacier upload-multipart-part --body $jail_back_loc/$tmpd/$file --range "bytes $byteStart-$byteEnd/*" --account-id - --vault-name $vaultname --upload-id="$uploadid")
		else
			byteStart=$((i*partsize))
			byteEnd=$((i*partsize+partsize-1))
			#Getting filename for part
			file=$(echo $f | sed 's:.*/::')
			checksum=$(jexec $(jid $back_jail) aws glacier upload-multipart-part --body $jail_back_loc/$tmpd/$file --range "bytes $byteStart-$byteEnd/*" --account-id - --vault-name $vaultname --upload-id="$uploadid")
			i=$(($i+1))
		fi
	done
	#Finishing upload
	result=$(jexec $(jid $back_jail) aws glacier complete-multipart-upload --account-id - --vault-name $vaultname --archive-size $filesize --checksum $hash --upload-id="$uploadid")
	rm -rf $tmppath

else
	#Uploading to Glacier normally
	echo $(date '+%b %d %H:%M:%S') $(hostname -s) backup: Uploading to Glacier >> $backup_log
	result=$(jexec $(jid $back_jail) aws glacier upload-archive --account-id - --vault-name $vaultname --body $jail_back_loc/$filename --archive-description $jailpath --checksum $hash)
	#echo -n
fi

archiveId=$(echo $result | jq -r .archiveId)

echo $(date '+%b %d %H:%M:%S') $(hostname -s) backup: Finished backup of jail $jail saved to $archiveId >> $backup_log

#Checking for old backups to prune
pruned=$(find $back_loc -maxdepth 1 -name "$jail*.gz" -mtime +$prunedays -print -type f -exec rm {} \; | sed "s:$back_loc/::" | tr "\n" " ")
if [[ $(test -z "$pruned" ;echo $?) -eq 0 ]];
    then
        echo $(date '+%b %d %H:%M:%S') $(hostname -s) prune: Nothing to prune >> $backup_log
else
        echo $(date '+%b %d %H:%M:%S') $(hostname -s) prune: Pruned $pruned >> $backup_log
fi
