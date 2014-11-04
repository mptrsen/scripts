#!/bin/bash

while read PEPTIDES TRANSCRIPTS; do
	file=$(basename $PEPTIDES)
	echo -n "$file... "
	perl /home/mpetersen/scripts/exonerate-corresponding-ogs.pl $PEPTIDES $TRANSCRIPTS > /tmp/log-$file
	echo "done"
done < /tmp/ogs.txt
