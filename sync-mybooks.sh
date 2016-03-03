#!/bin/bash

# keep 2 old log files
LOGFILE='/tmp/extbackup.log'
OLDLOGFILE=${LOGFILE}.1
OLDERLOGFILE=${LOGFILE}.2
mv $OLDLOGFILE $OLDERLOGFILE
mv $LOGFILE $OLDLOGFILE

SOURCE="/mnt/MYBOOK_A/"
DEST="/mnt/MYBOOK_B/"

# mount the destination
mount $DEST

# set options
OPTIONS="-v --archive --update --hard-links --delete --log-file=$LOGFILE"

# synchronize locations A and B
rsync $OPTIONS $SOURCE $DEST

if (($? > 0)); then
	ERROR=$?
	echo "###" >> $LOGFILE
	echo "done, errors occurred" >> $LOGFILE
fi

# done, unmount
umount $DEST

if (($ERROR > 0)); then
	# mail report if errors occurred
	SMTP="smtp=smtp.uni-bonn.de"
	FROMADDR="mptrsen@uni-bonn.de"
	TOADDR=$FROMADDR
	SUBJECT="Sync log: Error code $ERROR"
	mailx -S "$SMTP" -r $FROMADDR -s "$SUBJECT" $TOADDR < $LOGFILE
fi
