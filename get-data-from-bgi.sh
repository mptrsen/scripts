#!/bin/bash

# make sure we have enough arguments
if [ $# -lt 3 ]; then
	echo "Error: must be called with 3 args (HOST, USER, PASS) and 1 optional arg (DIRECTORY_PREFIX)"
	exit 1
fi
# optional: get prefix from fourth argument or fall back to default
if [ $# -gt 3 ]; then
	PREFIX=$4
else
	PREFIX="/var/data/graduateschool/data/.store/gbr"
fi

HOST=$1
USER=$2
PASS=$3
ERRORS=0

###########################
# function definitions
###########################
# log to both stdout and the log file
function log {
	NOW=$(date +%Y-%m-%dT%H:%M:%S)
	echo "$NOW $USER@$HOST $*"
	echo "$NOW $USER@$HOST $*" >> $PREFIX/download.status
}

# warning. log and increment error count
function warn {
	log $*
	let ERRORS++
}

# delete a file including warning on failure
function delete {
	if rm -f $*; then return 1
	else warn "remove of $* failed"
	fi
}

# die with an error message
function die {
	warn $*
	exit 1
}

###########################
# main
###########################

# ok, let's start. create output dir and go there
OUTPUT_DIRECTORY="$PREFIX/$USER@$HOST"
log "creating output directory '$OUTPUT_DIRECTORY'"
mkdir "$OUTPUT_DIRECTORY"
cd "$OUTPUT_DIRECTORY" || die "Could not chdir to '$OUTPUT_DIRECTORY'"

# log file name
LOGFILE="download-$USER@$HOST.log"

# the complete command
GET="wget --recursive --level=inf --backups=10000 --no-host-directories --continue --timestamping --append-output=$LOGFILE --user=$USER --password=$PASS ftp://$HOST"

# try downloading until it succeeds
log "download started"
while ! $GET ; do
  echo "retrying..." >> $LOGFILE
done
log "download finished"

# get the new directory name from the log file
NEWDIRS=$(grep -m 1 'CWD .\+ done' $LOGFILE | cut -d ' ' -f 4 | sed -e 's#^/##')
# get the md5 file name from the log file
MD5FILES=$(grep -o "[^\`]\+md5.txt\.*' saved" $LOGFILE | sed -e "s/' saved//") || warn "no md5 file found"
# get the report file name(s) from the log file
UPLOADFILES=$(grep -o  "=> [^ ]\+\(report\|upload\).tar.gz" $LOGFILE | sed -e 's/^[^A-Za-z]\+//') || warn "no report file found"

# rename the report package so file names aren't identical anymore
# use --no-clobber so existing target files don't get overwritten
for file in $UPLOADFILES; do
	REPORTFILE="$(dirname $file)/report-$USER.tar.gz"
	log "renaming $file to $REPORTFILE"
	mv --no-clobber $file $REPORTFILE || warn "rename failed"
done


# make a copy of the md5 file in case other processes finish while we're testing
CURDIR=$(pwd)
for file in $MD5FILES; do

	cd $(dirname $file)
	newfile="$USER.md5"
	log "renaming $file to $newfile"
	mv $(basename $file) $newfile || warn "rename failed" 

	# test the md5 checksums
	log "testing MD5 checksums in $newfile"
	if md5sum -c $newfile; then # everything ok
		log "MD5 checksums OK"
		# append the new md5 checksums to the main md5 file and remove the others
		cat $newfile >> md5sums.txt
		delete md5.check
	else # oops, something wrong with the md5 checksums
		warn "MD5 checksums not OK"
		# append the new checksums to the failed md5 file and remove the others, then die
		cat $newfile >> md5.failed
		delete md5.check
	fi

	# test gzip compression integrity
	log "testing compressed file integrity"
	while read CHECKSUM GZFILE; do
		if gzip -t $GZFILE; then
			log "$GZFILE gzip OK"
		else
			warn "$GZFILE gzip not OK"
		fi
	done < $newfile

	# remove old md5 file
	rm $newfile

	# re-create the directory tree listing; I hate the chinese
	# with their inconsistent naming scheme
	rm [rR]eadme.txt
	tree > readme.txt
	log "recreated directory listing"

	# go back to the previous dir
	cd $CURDIR

done

log "done, $ERRORS errors"

# send notification mail
echo "Subject: Download for $USER complete: $ERRORS errors" | tail -q -n 3 - $LOGFILE | sendmail -F Gaia -t mptrsen@uni-bonn.de
log "notification mail sent"

# and, if everything went ok, exit successfully
if [ $ERRORS -eq 0 ]; then 
	exit 0
else # otherwise... not
	exit 1
fi
