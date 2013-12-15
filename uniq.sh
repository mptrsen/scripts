#!/bin/bash

# find duplicate sequence identifiers in a Hamstrad result directory.
# run as:
#
#   uniq.sh [DIR]
#
# where DIR is a directory to examine for the data. If DIR is left empty, the
# current directory is examined. z.B. outputhamstr
# ACHTUNG: Eingabe: sh unique.sh wobei das shell dann im ordner mit den outputordnern liegt: Anurida_maritima ... bla mit 3 unterordnern
# er gibt auf den screen die header aus, die mehrfach vorkommen.
# über grep "xxx"  kann man dann die Gene abgreifen: grep "header" *.fa

# set to current directory if none was provided via arguments
if [ -z $1 ]; then
	dir='.'
else 
	dir=$1
fi

# die if this is not a directory
if [ ! -d $dir ]; then
	echo "Error: $dir is not a directory"
	exit 1
fi

# for all top-level directories that do not start with a '.'
# but not for their subdirectories (-maxdepth 1), do the following
for subdir in $(find $dir -maxdepth 1 -type d ! -iname '.*'); do \

# print directory name
	echo "$subdir: "; 

# for every file in dir/aa/*.fa
	for file in $subdir/aa/*.fa; do \

# extract the relevant ID, remove length information, convert 'PP' to newline
		tail -n 2 $file | head -n 1 | sed -e 's/.*|//' | sed -e 's/-[0-9]*//g' | sed -e 's/PP/\n/g'; 

# finished extracting from the files, check for duplicates
	done | uniq -d; 

# done
done


