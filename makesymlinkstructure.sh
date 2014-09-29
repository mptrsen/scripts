#!/bin/bash
# author: Malte Petersen
# create directory structure with symlinks according to input table

# exit on any error
set -e

USAGE=$(cat <<EOF
Usage: $0 TABLEFILE

TABLEFILE needs to have the following columns, tab-separated (X, Y and Z are irrelevant):

SPECIES TYPE LIBSIZE X Y USER HOST Z PROJECT DIR FILES

Lines that begin with a '#' are ignored.
 
EOF
)

function die {
	echo "Error: $*"
	exit 1
}

if [ $# -ne 1 ]; then 
	echo "$USAGE"
	die "argument required"
fi

PREFIX="/tmp"

# all lines that aren't commented out in the input file: get the relevant columns
grep -v '^#' $1 | cut -f 1,2,3,6,7,9,10,11 | while read SPECIES TYPE LIBSIZE USER HOST PROJECT DIR FILES; do
	# generate output directory name and create it
	OUTDIR="$PREFIX/by-species/$SPECIES/$TYPE/${LIBSIZE}bp"
	MKOUTDIR="mkdir -p $OUTDIR"
	$MKOUTDIR || die "could not make directory: $?"

	# split the list of files and make a link for each
	echo $FILES | sed -e 's/;/\n/g' | while read FILE; do
		INFILE="$USER@$HOST/$PROJECT/$DIR/Clean/$FILE"
		if [ ! -f $INFILE ]; then
			die "no such file or directory: $INFILE"
		fi
		LINKAGE="ln -s $INFILE $OUTDIR/$FILE"
		$LINKAGE || die "failed to create link"
	done
done

