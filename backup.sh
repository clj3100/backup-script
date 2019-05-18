#!/bin/bash

backup_loc=/mnt/Backup

#Defining function for getting the jail ID
function jid {

jls | grep "$1" | awk '{print $1}'

}

#Defining a function to get the zfs path of the jail
function jpath {

zfs list | grep "$1" | grep root |awk '{print $1}'

}
