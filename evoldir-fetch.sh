#!/bin/bash

# settings
export MAILRC=/dev/null
TOADDR="mptrsen@uni-bonn.de"
FROMADDR="mptrsen@uni-bonn.de"
SMTP="smtp=smtp.uni-bonn.de"
SUBJECT="Evoldir last day"
URLS="http://evol.mcmaster.ca/~brian/evoldir/last.day http://evol.mcmaster.ca/~brian/evoldir/last.day-1 http://evol.mcmaster.ca/~brian/evoldir/last.day-2"
FILE="/tmp/evoldir.last.day.txt"

# fetch the daily text files from evoldir
wget --output-file=/dev/null --output-document=$FILE $URLS

# edit the signature separator because mail clients suck
sed -i -e 's/^--/---/' $FILE

# gimme gimme gimme 
mailx -S "$SMTP" -r $FROMADDR -s "$SUBJECT" $TOADDR < $FILE
