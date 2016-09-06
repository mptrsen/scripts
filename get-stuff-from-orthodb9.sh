#!/bin/bash

# Copyright 2016, Malte Petersen <mptrsen@uni-bonn.de>
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

# this function fetches data from orthodb and makes sure we don't get html back
fetch_to_file() {
	curl -s "$1" > "$2"
	while grep '^<html>' "$2" > /dev/null; do
		echo "  Something wrong, retrying..."
		curl -s "$1" > $2
	done
}

# Input should be a single valid OrthoDB URL
if [ $# -ne 1 ]; then 
	echo "Usage: $0 'ORTHODB9_URL'"
	echo "The quotes are important, do not omit them!"
	exit 1
fi
URL=$1
if [[ ! "$URL" =~ ^http://www.orthodb.org/ ]]; then
	echo "Not a valid OrthoDB URL: '$URL'"
	exit 1
fi

# Get the number of EOGs
echo "URL: '$URL'"
URL=${URL/\?/search?}
NUM_OG=$(curl -s $URL | grep -Po 'count": [0-9]+' | sed -e 's/count": //')
echo "Number of OGs: $NUM_OG"

# set the limit to that number
URL=${URL/\?/?limit=$NUM_OG&}

# setup output file names
PREFIX="orthodb9_query_$(date +%s)"
LISTFILE="${PREFIX}_list.txt"
TABLEFILE="${PREFIX}_table.txt"
FASTAFILE="${PREFIX}_sequences.fa"

# fetch the list of OGs
echo "List file: $LISTFILE"
curl -s $URL \
	| grep -Po '"data": \[[^]]+\]' \
	| sed -e 's/^"data": \["//' -e 's/"\]$//' -e 's/", "/\n/g' \
	> $LISTFILE

# get the table header
fetch_to_file "${URL/search\?/tab?query=$(head -n 1 $LISTFILE)&}" $TABLEFILE
TABLE_HEADER=$(head -n 1 "$TABLEFILE")

# fetch all the table lines and fasta files
declare -i i=0
cat $LISTFILE | while read OG; do 
	let i++
	echo "Fetching table for $OG ($i of $NUM_OG)"
	OG_TABLE_FILE=${PREFIX}_$OG.txt
	TABLE_URL=${URL/search\?/tab?query=$OG&}
	fetch_to_file "$TABLE_URL" $OG_TABLE_FILE
	echo "Fetching fasta for $OG ($i of $NUM_OG)"
	OG_FASTA_FILE=${PREFIX}_$OG.fa
	FASTA_URL=${URL/search\?/fasta?query=$OG&}
	fetch_to_file "$FASTA_URL" $OG_FASTA_FILE
done

echo "Combining tables"
echo "$TABLE_HEADER" > $TABLEFILE
tail -q -n +2 ${PREFIX}_?OG*.txt >> $TABLEFILE
echo "Combining fastas"
cat ${PREFIX}_?OG*.fa > $FASTAFILE
echo "Done."
echo "Output table: $TABLEFILE"
echo "Output fasta: $FASTAFILE"
