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

echo "######## Music file tagger ########"
echo

append=0
verbose=0

# options:
# -a : append (preserve existing tags)
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

# make file list first
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

# function: delete-tags
# function: add-tags

let n=0 # counter
for file in "$@"; do
	printf "# Tagging %s #\n" "$file"
	# list existing tags if verbose (-v)
	if [[ $verbose -ne 0 ]]; then
		printf "## Existing tags:\n"
		if [[ "${file^^}" =~ mp3$ ]]; then
			id3v2 --list-rfc822 "$file"
		elif [[ "${file^^}" =~ ogg$ ]]; then
			vorbiscomment --list "$file"
		fi
	fi
	# get file-specific infos, allow editing of globals
	read -e -p "Artist: " -i "$ART"
	read -e -p "Album:  " -i "$ALB"
	read -e -p "Year:   " -i "$YER"
	read -e -p "Title:  "      TIT
	read -e -p "Track:  "      TRK
	# use different programs depending on file type
	if   [[ "${file^^}" =~ mp3$ ]]; then # is an mp3 file
		if [[ $append -eq 0 ]]; then
			id3v2 --delete "$file"
		fi
		id3v2 \
			--artist "$ART" \
			--album  "$ALB" \
			--year   "$YER" \
			--track  "$TRK/$NUM" \
			--song   "$TIT" \
			"$file" || exit 1
	elif [[ "${file^^}" =~ ogg$ || "$file" =~ OGG$ ]]; then # is an ogg vorbis file
		if [[ $append -eq 0 ]]; then
			# delete all tags
			vorbiscomment --write --commentfile /dev/null "$file" || exit 1
		fi
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
	echo
done

printf "# Done: Tagged %d files. Bye.\n" $n
