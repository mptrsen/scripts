#!/bin/bash

# Copyright 2017, Malte Petersen
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

######################################
###            Functions           ###
######################################

# deletes all tags from a file
function striptags {
	shopt -s nocasematch
	if   [[ "$1" =~ mp3$ ]]; then
		# delete id3v2 tags
		id3v2 --delete-all "$1" || exit 1
	elif [[ "$1" =~ ogg$ ]]; then
		# delete vorbis comments
		vorbiscomment --write --commentfile /dev/null "$1" || exit 1
	fi
	shopt -u nocasematch
}

# lists all tags in a file
function listtags {
	shopt -s nocasematch
	if   [[ "$1" =~ mp3$ ]]; then
		# delete id3v2 tags
		id3v2 --list-rfc822 "$1" || exit 1
	elif [[ "$1" =~ ogg$ ]]; then
		# delete vorbis comments
		vorbiscomment --list "$1" || exit 1
	fi
	shopt -u nocasematch
}

######################################
###        Begin main block        ###
######################################

echo "######## Music file tagger ########"
echo

# command line options:
# -a : append (preserve existing tags)
# -v : verbose (list existing tags before editing)
append=0
verbose=0
while getopts "av" option; do
	case "$option" in
		a)
			append=1
			;;
		v)
			verbose=1
			;;
	esac
	# remove option from parameter list
	shift $((OPTIND-1))
done

# no files provided
if [[ $# -lt 1 ]]; then
	echo "Error: No files"
	exit 1
fi

# print file list first
echo "# Files #"
declare -i n=0 # counter
for file in "$@"; do
	let n++
	printf "%02d: %s\n" $n "$file"
done

# spacer
echo

# get global vars
echo "# Global #"
read -p "Artist: " ART
read -p "Album:  " ALB
read -p "Year:   " YER
read -p "Tracks: " NUM

# spacer
echo

shopt -s nocasematch # case-insensitive pattern matching
let n=0 # counter
for file in "$@"; do

	printf "# Tagging %s #\n" "$file"

	# list existing tags if verbose (-v)
	if [[ $verbose -ne 0 ]]; then
		echo "## Existing tags:"
		listtags "$file"
	fi

	# remove existing tags
	if [[ $append -eq 0 ]]; then
		striptags "$file"
	fi

	# get file-specific infos, allow editing of globals
	unset TIT TRK # need no defaults
	read -e -p "Artist: " -i "$ART" ART
	read -e -p "Album:  " -i "$ALB" ALB
	read -e -p "Year:   " -i "$YER" YER
	read -e -p "Title:  "           TIT
	read -e -p "Track:  "           TRK

	# actually write tags: use different programs depending on file type
	if   [[ "$file" =~ mp3$ ]]; then # is an mp3 file
		id3v2 \
			--artist "$ART" \
			--album  "$ALB" \
			--year   "$YER" \
			--track  "$TRK/$NUM" \
			--song   "$TIT" \
			"$file" || exit 1
	elif [[ "$file" =~ ogg$ ]]; then # is an ogg vorbis file
		# write new tags
		vorbiscomment --write --append\
			--tag "ARTIST=$ART" \
			--tag "ALBUM=$ALB" \
			--tag "DATE=$YER" \
			--tag "TRACKNUMBER=$TRK" \
			--tag "TITLE=$TIT" \
			"$file" || exit 1
	fi

	let n++ # counter

	# spacer
	echo

done

printf "# Done: Tagged %d files. Bye.\n" $n
