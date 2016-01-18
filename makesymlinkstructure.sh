#!/bin/bash
# author: Malte Petersen
# create directory structure with symlinks according to input table

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
	echo "$USAGE"
	die "argument required"
fi

PREFIX="/var/data/graduateschool/data"
DATADIR="$PREFIX/.store/gbr"

# make sure the table is right
NUMBER_OF_COLUMNS=$( awk '{ print NF; exit }' $1 )
if [ $NUMBER_OF_COLUMNS -ne 12 ]; then
	echo $USAGE
	die "Invalid number of columns in $1"
fi

# clear existing directory structure
echo "Clearing existing directory structure..."
rm -rf /var/data/graduateschool/data/by-*

# all lines that aren't commented out in the input file: get the relevant columns
grep -v '^#' $1 | cut -f 1,2,3,6,7,9,10,11 | while read SPECIES TYPE LIBSIZE USER HOST PROJECT DIR FILES; do
	# generate output directory name and create it
	OUTDIR_BYSPECIES="$PREFIX/by-species/$SPECIES/$TYPE/${LIBSIZE}bp"
	mkdir -p $OUTDIR_BYSPECIES || die "could not make directory: $?"
	OUTDIR_BYTYPE="$PREFIX/by-type/$TYPE/$SPECIES/${LIBSIZE}bp"
	mkdir -p $OUTDIR_BYTYPE || die "could not make directory: $?"

	# are there any files at all?
	if [ $FILES ]; then
		# split the list of files and make a link for each
		echo $FILES | sed -e 's/;/\n/g' | while read FILE; do
			# the actual files
			TARGET=$(find "$DATADIR/$USER@$HOST/$PROJECT" -type f -name "$FILE")
			LINK_BYSPECIES="$OUTDIR_BYSPECIES/$FILE"
			LINK_BYTYPE="$OUTDIR_BYTYPE/$FILE"
			# the md5sum files
			TARGET_MD5="$TARGET.md5"
			LINK_BYSPECIES_MD5="$OUTDIR_BYSPECIES/$FILE.md5"
			LINK_BYTYPE_MD5="$OUTDIR_BYTYPE/$FILE.md5"
			if [ ! -f $TARGET ]; then
				die "no such file or directory here: $TARGET"
			fi
			# make the links
			echo "$LINK_BYSPECIES --> $TARGET"
			ln -s $TARGET $LINK_BYSPECIES || die "could not make link: exiting"
			echo "$LINK_BYTYPE --> $TARGET"
			ln -s $TARGET $LINK_BYTYPE || die "could not make link: exiting"
			# also for the md5sum files
			echo "$LINK_BYTYPE_MD5 --> $TARGET_MD5"
			ln -s $TARGET_MD5 $LINK_BYTYPE_MD5 || die "could not make link: $?"
			echo "$LINK_BYSPECIES_MD5 --> $TARGET_MD5"
			ln -s $TARGET_MD5 $LINK_BYSPECIES_MD5 || die "could not make link: $?"
		done
	# otherwise, just link the directory
	else
		TARGET=$(find "$DATADIR/$USER@$HOST/$PROJECT" -type d -name "$DIR")
		LINK_BYSPECIES="$OUTDIR_BYSPECIES"
		LINK_BYTYPE="$OUTDIR_BYTYPE"
		if [ ! -d $TARGET ]; then
			die "Waah: no such file or directory: $TARGET"
		fi
		echo "$LINK_BYSPECIES --> $TARGET"
		ln -s $TARGET $LINK_BYSPECIES || die "could not make link: $?"
		echo "$LINK_BYTYPE --> $TARGET"
		ln -s $TARGET $LINK_BYTYPE || die "could not make link: $?"
	fi
done

#echo "Fixing permissions"
#find "$PREFIX/by-species" -type l -exec chmod 444 {} \; # links
#find "$PREFIX/by-species" -type d -exec chmod 555 {} \; # dirs
#find "$PREFIX/by-type"    -type l -exec chmod 444 {} \; # links
#find "$PREFIX/by-type"    -type d -exec chmod 555 {} \; # dirs
echo "Done"
