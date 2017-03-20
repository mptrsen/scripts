#!/bin/bash

# keep 2 old log files
LOGFILE='/var/tmp/extbackup.log'
OLDLOGFILE=${LOGFILE}.1
OLDERLOGFILE=${LOGFILE}.2
mv $OLDLOGFILE $OLDERLOGFILE
mv $LOGFILE $OLDLOGFILE

SOURCE="/mnt/MYBOOK_A"
DEST="/mnt/MYBOOK_B"

# mount the destination
mount $DEST

# set options
OPTIONS="-v --archive --update --delete --log-file=$LOGFILE"

# log function, writes everything to LOGFILE
function log() {
	echo "$@" >> $LOGFILE
}

# copy irclogs
log "## Backing up irclogs"
rsync -auv --delete --log-file=$LOGFILE ~/irclogs/ $SOURCE/irclogs/
log

# copy dropbox and sciebo contents
log "## Backing up Dropbox"
rsync -auv --log-file=$LOGRILE ~/Dropbox/ $SOURCE/dropbox-local/
log
log "## Backing up Sciebo"
rsync -auv --log-file=$LOGRILE ~/Sciebo/ $SOURCE/sciebo-local/
log

# synchronize locations A and B
for DIR in $(ls --color=no $SOURCE | grep -v '^lost+found$'); do
	log "## Synchronizing $SOURCE/$DIR and $DEST/$DIR"
	rsync $OPTIONS "$SOURCE/$DIR/" "$DEST/$DIR/"
	log
done

if (($? > 0)); then
	ERROR=$?
	log "###"
	log "done, errors occurred"
else
	ERROR=0
fi

# done, unmount
umount $DEST

if [ $ERROR -gt 0 ]; then
	# mail report if errors occurred
	SMTP="smtp=smtp.uni-bonn.de"
	FROMADDR="mptrsen@uni-bonn.de"
	TOADDR=$FROMADDR
	SUBJECT="Sync log: Error code $ERROR"
	mailx -S "$SMTP" -r $FROMADDR -s "$SUBJECT" $TOADDR < $LOGFILE
fi
