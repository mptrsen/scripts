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

# options:
# -a : append (preserve existing tags)
while getopts "a" option; do
	case "$option" in
		a)
			append=1
			;;
	esac
	# remove option from parameter list
	shift $((OPTIND-1))
done

function die {
	echo "$@"
	exit 1
}

# make file list first
echo "# Files #"
for file in "$@"; do
	printf "%s\n" "$file"
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

declare -i n=0
for file in "$@"; do
	printf "# Tagging %s #\n" "$file"
	printf "Artist: %s\n"     "$ART"
	printf "Album:  %s\n"     "$ALB"
	printf "Year:   %s\n"     "$YER"
	read -p "Title:  "         TIT
	read -p "Track:  "         TRK
	# use different programs depending on file type
	if   [[ "$file" =~ mp3$ || "$file" =~ MP3$ ]]; then # is an mp3 file
		id3v2 \
			--artist "$ART" \
			--album  "$ALB" \
			--year   "$YER" \
			--track  "$TRK/$NUM" \
			--song   "$TIT" \
			"$file" || die
	elif [[ "$file" =~ ogg$ || "$file" =~ OGG$ ]]; then # is an ogg vorbis file
		if [[ $append -eq 0 ]]; then
			# delete all tags
			vorbiscomment --write --commentfile /dev/null "$file"
		#--------------------------------------------------
		# else 
		# 	# save existing tags to a file
		# 	vorbiscomment -l "$file" > .tags.tmp
		# 	# write existing tags
		# 	vorbiscomment --write --commentfile '.tags.tmp' "$file"
		# 	# delete comment file
		# 	rm .tags.tmp
		#-------------------------------------------------- 
		fi
		# write new tags
		vorbiscomment --write --append\
			--tag "ARTIST=$ART" \
			--tag "ALBUM=$ALB" \
			--tag "DATE=$YER" \
			--tag "TRACKNUMBER=$TRK" \
			--tag "TITLE=$TIT" \
			"$file" || die
	fi
	let n++ # counter
	echo
done

printf "# Done: Tagged %d files\n" $n
