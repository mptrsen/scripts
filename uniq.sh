#!/bin/bash

# find duplicate sequence identifiers in a Hamstrad result directory.
# run as:
#
#   uniq.sh
#
# in the data/ directory. Will look in all subdirectories, but not in
# sub-subdirectories etc. These have to contain a directory called 'aa', where
# the result fasta files must reside (standard Hamstrad output).

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


# for every directory (-type d) in the current dir (.), 
# but not for their subdirectories (-maxdepth 1)
for subdir in $(find $dir -maxdepth 1 -type d); do \

# print directory name
	echo "Duplicates in $subdir: "; 

# for every file in dir/aa/*.fa
	for file in $subdir/aa/*.fa; do \

# extract the relevant ID
		tail -n 2 $file | head -n 1 | sed -e 's/.*|//' | sed -e 's/PP/\n/g'; 

# finished extracting from the files, check for duplicates
	done | uniq -d; 

# done
done


