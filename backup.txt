#!/bin/bash
: ' #START OF COMMENTS

#NEED TO DO

#Setup cron jobs on Backup Machine

Runs every x minutes to make and rotate snapshots
10 * * * * /usr/local/bin/backItUp >/dev/null

Runs once a night at 11p.m. to rotate daily snapshots
0 23 * * * /usr/local/bin/backItUp daily >/dev/null

#Setup Exclude/Include Files

I did some alterations as I wanted to backup more than just
the home dir. The include file determines what is to be
backed up now.

The new rsync command (now uses in and excludes and "/" as src) :
$RSYNC								\
	-va --delete --delete-excluded				\
	--exclude-from="$EXCLUDES"				\
	--include-from="$INCLUDES"				\
	/ $BACKUP_RW/home/daily.0 ;

Exclude file (the stuff we dont want) :
#rsync script exclude file
**/.pan/messages/cache/
**/.phoenix/default/*/Cache/
**/.thumbnails/
**/Desktop/Trash/

Include (what dirs to be included):
#rsync script include file
/home/
/home/**
/var/
/var/www/
/var/www/**
/etc/
/etc/**
- *

Note the "- *" for excluding everything except the dirs mentioned
in the include file.
Also note the "/var/" entry. To backup /var/www/* , you need to
include /var/

###NFS SOLUTION

My solution: using NFS on localhost

This is a bit more complicated, but until Linux supports mount --bind with different access permissions in different places, it seems like the best choice. Mount the partition where backups are stored somewhere accessible only by root, such as /root/snapshot. Then export it, read-only, via NFS, but only to the same machine. That's as simple as adding the following line to /etc/exports:

/root/snapshot 127.0.0.1(secure,ro,no_root_squash)
then start nfs and portmap from /etc/rc.d/init.d/. Finally mount the exported directory, read-only, as /snapshot:

mount -o ro 127.0.0.1:/root/snapshot /snapshot
And verify that it all worked:

mount
...
/dev/hdb1 on /root/snapshot type ext3 (rw)
127.0.0.1:/root/snapshot on /snapshot type nfs (ro,addr=127.0.0.1)
At this point, we'll have the desired effect: only root will be able to write to the backup (by accessing it through /root/snapshot). Other users will see only the read-only /snapshot directory. For a little extra protection, you could keep mounted read-only in /root/snapshot most of the time, and only remount it read-write while backups are happening.


' #END OF COMMENTS

###VARIABLES###

DATE=$(date +%m%d%y-%H%M%S)

# SYSTEM COMMANDS
ID=/usr/bin/id;
ECHO=/bin/echo;
MOUNT=/bin/mount;
RM=/bin/rm;
CP=/bin/cp;
TOUCH=/bin/touch;
RSYNC=/usr/bin/rsync;
MV=my_mv; #Function to maintain timestamp integrity of backed up files

# FILE LOCATIONS
SOURCE_DIR= 																		#Directory to backup; MUST HAVE TRAILING SLASH
DEST_DIR='$BACKUP_RW/${DATE}-backup.hourly.0'			#The Destination where you want to sync the files to
MOUNT_DEVICE=/dev/hdb1;													#Device to Back it up to
BACKUP_RW=/root/backup;													#Back up Directory we are mounting
EXCLUDES=/usr/local/etc/backup_exclude;					#Directory we want to exclude from backing up

###############

function my_mv() {	#Preserves original timestamps when moving files
   REF=/tmp/.makeBackup-myMv-$$;
   touch -r $1 $REF;
   /bin/mv $1 $2;
   touch -r $REF $2;
   /bin/rm $REF;
}

function check.root {	# Make sure you are root
	if [[ `$ID -u` != 0 ]]; then
		$ECHO "Sorry, must be root.  Exiting..."
		exit 0
	fi
}

function mount.rw {	# Remount the RW mount point as RW; or exit
	$MOUNT -o remount,rw $MOUNT_DEVICE $BACKUP_RW
	if [[ $? ]]; then
		$ECHO "snapshot: could not remount $SNAPSHOT_RW readwrite";
		exit 0
	fi
}

function mount.ro {	# Remount the RW mount point as RO
	$MOUNT -o remount,ro $MOUNT_DEVICE $BACKUP_RW ;
	if [[ $? ]]; then
		$ECHO "Snapshot: could not remount $BACKUP_RW readonly"
		exit 0
	fi
}

function log.rotate.hourly {	#Rotate the last 5 backups and backup every hour

# Delete oldest backup
if [ -d $BACKUP_RW/${DATE}-backup.hourly.5 ]; then
	$RM -rf $BACKUP_RW/${DATE}-backup.hourly.5
fi

# Rotate all existing (Up to 5) backups back by one
if [ -d $BACKUP_RW/${DATE}-backup.hourly.4 ] ; then
	$MV $BACKUP_RW/${DATE}-backup.hourly.4 $BACKUP_RW/${DATE}-backup.hourly.5
fi

if [ -d $BACKUP_RW/${DATE}-backup.hourly.3 ] ; then
	$MV $BACKUP_RW/${DATE}-backup.hourly.3 $BACKUP_RW/${DATE}-backup.hourly.4
fi

if [ -d $BACKUP_RW/${DATE}-backup.hourly.2 ] ; then
	$MV $BACKUP_RW/${DATE}-backup.hourly.2 $BACKUP_RW/${DATE}-backup.hourly.3
fi

if [ -d $BACKUP_RW/${DATE}-backup.hourly.1 ] ; then
	$MV $BACKUP_RW/${DATE}-backup.hourly.1 $BACKUP_RW/${DATE}-backup.hourly.2
fi

if [ -d $BACKUP_RW/${DATE}-backup.hourly.0 ] ; then
	$MV $BACKUP_RW/${DATE}-backup.hourly.0 $BACKUP_RW/${DATE}-backup.hourly.1
fi

#Perform backup of $SOURCE_DIR via rsync
if [ -d $BACKUP_RW/${DATE}-backup.hourly.1 ]; then
	rsync -va --delete --delete-excluded --exclude-from="$EXCLUDES" --link-dest=${BACKUP_RW}/${DATE}-backup.hourly.1 ${SOURCE_DIR} ${DEST_DIR}
else
	rsync -va --delete --delete-excluded --exclude-from="$EXCLUDES" ${SOURCE_DIR} ${DEST_DIR}
fi

}

function log.rotate.daily {

# Delete oldest backup
if [ -d $BACKUP_RW/${DATE}-backup.daily.5 ]; then
	$RM -rf $BACKUP_RW/${DATE}-backup.daily.5
fi

#using normal mv because we dont' want to update mtime of daily.0
#It should reflect when hourly.0 was made which should be correct

# Rotate all existing (Up to 5) backups back by one
if [ -d $BACKUP_RW/${DATE}-backup.daily.4 ] ; then
	/bin/mv $BACKUP_RW/${DATE}-backup.daily.4 $BACKUP_RW/${DATE}-backup.daily.5
fi

if [ -d $BACKUP_RW/${DATE}-backup.daily.3 ] ; then
	/bin/mv $BACKUP_RW/${DATE}-backup.daily.3 $BACKUP_RW/${DATE}-backup.daily.4
fi

if [ -d $BACKUP_RW/${DATE}-backup.daily.2 ] ; then
	/bin/mv $BACKUP_RW/${DATE}-backup.daily.2 $BACKUP_RW/${DATE}-backup.daily.3
fi

if [ -d $BACKUP_RW/${DATE}-backup.daily.1 ] ; then
	/bin/mv $BACKUP_RW/${DATE}-backup.daily.1 $BACKUP_RW/${DATE}-backup.daily.2
fi

if [ -d $BACKUP_RW/${DATE}-backup.daily.0 ] ; then
	/bin/mv $BACKUP_RW/${DATE}-backup.daily.0 $BACKUP_RW/${DATE}-backup.daily.1
fi

#Perform Daily backup using copy of the most recent hourly backup
if [ -d $BACKUP_RW/${DATE}-backup.hourly.0 ] ; then
	$CP -al $BACKUP_RW/${DATE}-backup.hourly.0 $BACKUP_RW/${DATE}-backup.daily.0
fi

}

###BEGIN SCRIPT###

check.root
mount.rw

if [ $1 == "daily" ]; then
	log.rotate.daily
elif [ $1 == "hourly" ]; then
	log.rotate.hourly
else
	echo "USAGE: $0 daily|hourly"
	exit 0
fi

mount.ro
exit 0