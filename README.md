FreeBSD jail backup script

Backs up to local directory and to AWS glacier

Requires a jail that has aws-cli installed and configured
also needs the backup location in fstab on the jail in desired location

All configuration is in the back.conf file

It can be setup and installed using the init.sh script which will setup the jail and download the rest of the scripts

`curl https://raw.githubusercontent.com/clj3100/backup-script/master/init.sh | bash`
