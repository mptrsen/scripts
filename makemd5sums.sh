#!/bin/bash

set -e

USAGE=$(cat <<EOF
Usage: $0 TABLEFILE

TABLEFILE needs to have the following columns, tab-separated (X, Y, Z and ZZ are irrelevant):

SPECIES TYPE LIBSIZE X Y USER HOST Z PROJECT DIR FILES ZZ

FILES is a semicolon-separated list of files. Lines that begin with a '#' are ignored.
 
EOF
)

function die {
	echo "Error: $*"
	exit 1
}

if [ $# -ne 1 ]; then 
	echo $USAGE
	exit 1
fi


PREFIX="/var/data/graduateschool/data/.store/gbr"

# make sure the table is right
NUMBER_OF_COLUMNS=$( awk '{ print NF; exit }' $1 )
if [ $NUMBER_OF_COLUMNS -ne 12 ]; then
	echo $USAGE
	die "Invalid number of columns in $1"
fi

# get relevant lines and columns and start
grep -v '^#' $1 | cut -f 1,2,3,6,7,9,10,11 | while read SPECIES TYPE LIBSIZE USER HOST PROJECT DIR FILES; do
	if [ $FILES ]; then
		echo $FILES | sed -e 's/;/\n/g' | while read FILE; do
			TARGET=$(find "$PREFIX/$USER@$HOST/$PROJECT" -type f -name "$FILE")
			cd $(dirname $TARGET)
			echo "md5sum $SPECIES $TYPE $LIBSIZE ($USER@$HOST:$PROJECT) $FILE > $TARGET.md5"
			if [ -e $FILE.md5 ]; then  # skip if md5 file exists
				continue
			fi
			md5sum $FILE > $FILE.md5
		done
	else
		TARGET=$(find "$PREFIX/$USER@$HOST/$PROJECT" -type d -name "$DIR")
		cd $TARGET
		if [ -e md5sums.txt ]; then  # skip if md5 file exists
			continue
		fi
		rm -f md5sums.txt
		echo "md5sum $SPECIES $TYPE $LIBSIZE ($USER@$HOST:$PROJECT) > $TARGET/md5sums.txt"
		md5sum * > md5sums.txt
	fi
done
