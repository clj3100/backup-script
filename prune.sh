#!/bin/bash

#Script to prune current backups from Glacier as the storage costs to get a little high after 2 or so TB

vault_name=backup-cjonesflix
backup_jail=Backup

#Defining function for getting the jail ID
function jid {

jls | grep "$1" | awk '{print $1}'

}
