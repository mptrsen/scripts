#!/bin/bash

# This script rips series from DVD to Matroshka format (including subtitles as
# separate tracks). It uses HandBrakeCLI, which must be installed. Do not use
# the version in the repositories as they are horribly outdated and broken. You
# can get the recent version of HandBrakeCLI for Ubuntu-based systems by adding
# this PPA from the author:
#
#   add-apt-repository ppa:stebbins/handbrake-releases
#   apt-get update
#   apt-get install handbrake-cli
#
# Usage:
# 
#   serien-ripper.sh -t "Title of the series" -s X -e Y [OPTIONS]
#
# Where X is the season and Y the number of episodes in the series.
# Options follow.

usage="
Usage:
	$0 -t \"Title of the series\" -s X -e Y [OPTIONS]

Mandatory parameters:

	-t, --title Title
		Set the title; use quotes if it contains spaces and other special
		characters. They will be removed to form a safe output file name.
	-s, --season N
		Set season. Must be integer.
	-e, --number-episodes N
		Set number of episodes. Must be integer.

Optional parameters:

	-1, --start-episode N
		(yes, that's a one.) Set starting episode. Must be integer. Useful if you
		want to start ripping in the middle. Defaults to 1.
	-d, --dvd-device DVD-DEVICE
		Set DVD device. Defaults to /dev/cdrom.
	-l, --languages LANGUAGES
		Specify languages. Must be a comma-separated list of ISO 639-2 language
		codes. Example: deu,eng. No default.
	-n, --episodes-per-dvd N
		Episodes per DVD. The script will eject the DVD and ask for the next one
		after each N episodes. Defaults to 2.
	-p, --preset-file PRESET_FILE
		HandBrake preset file. Usually not needed. No default.
"

#
#
# Functions
#
#

function is_int {
	if [[ "$1" =~ ^[0-9]+$ ]]; then
		return 0
	else
		return 1
	fi
}

function die {
	echo "Fatal: $@" >&2
	exit 1
}

function die_argument_missing {
	die "$1 requires a non-empty argument"
}

# options

if [[ $# -eq 0 ]]; then
	echo "$usage"
	exit 1
fi

while :; do
	case $1 in
		-1|--start-episode)
			if [[ "$2" ]]; then
				start_episode=$2
				shift
			else
				die_argument_missing "$1"
			fi
			is_int $start_episode || die "start episode must be integer"
			;;
		-d|--dvd-device)
			if [[ "$2" ]]; then
				dvd_device=$2
				shift
			else
				die_argument_missing "$1"
			fi
			;;
		-e|--number-episodes)
			if [[ "$2" ]]; then
				episodes=$2
				shift
			else
				die_argument_missing "$1"
			fi
			is_int $episodes || die "number of episodes must be integer"
			;;
		-h|--help)
			echo "$usage" && exit
			;;
		-l|--languages)
			if [[ "$2" ]]; then
				languages=$2
				shift
			else
				die_argument_missing "$1"
			fi
			;;
		-n|--episodes-per-dvd)
			if [[ "$2" ]]; then
				episodes_per_dvd=$2
				shift
			else
				die_argument_missing "$1"
			fi
			is_int $episodes_per_dvd || die "number of episodes per DVD must be integer"
			;;
		-p|--preset-file)
			if [[ "$2" ]]; then
				preset_file=$2
				shift
			else
				die_argument_missing "$1"
			fi
			;;
		-s|--season)
			if [[ "$2" ]]; then
				season=$2
				shift
			else
				die_argument_missing "$1"
			fi
			is_int $season || die "season must be integer"
			;;
		-t|--title)
			if [[ "$2" ]]; then
				title=$2
				shift
			else
				die_argument_missing "$1"
			fi
			;;
		-?*)
			die "Unknown option: $1"
			;;
		*)
			break
	esac
	shift
done

# got all parameters?

# mandatory
if [[ ! "$title"    ]]; then die "title not set. use -t to specify title"; fi
if [[ ! "$season"   ]]; then die "season not set. use -s to specify season"; fi
if [[ ! "$episodes" ]]; then die "number of episodes not set. use -e to specify episodes"; fi
# defaults to 1
start_episode=${start_episode:=1}
# defaults to 2
episodes_per_dvd=${episodes_per_dvd:=2}
# defaults to /dev/cdrom
dvd_device=${dvd_device:="/dev/cdrom"}
# defaults to nothing
lang_option=${languages:+"--subtitle-lang-list $languages --all-subtitles --audio-lang-list $languages --all-audio"}
# defaults to nothing
if [[ "$preset_file" ]]; then preset_option="--preset-import-file \"$preset_file\""; fi

# summarize parameters

echo "## Summary"
echo '----------------------------------------------'
echo "Title:            $title"
echo "Season:           $season"
echo "Episodes:         $episodes"
echo "Starting episode: $start_episode"
echo "Episodes per DVD: $episodes_per_dvd"
echo "Language(s):      $languages"
echo "HandBrake preset: $preset_file"
echo '----------------------------------------------'

# start ripping!

let episode=$start_episode-1
let counter=0
declare -a output_files # collect output file names in a list

while [[ $episode -lt $episodes ]]; do
	let counter++
	let episode++

	# need to switch to the next DVD if out of episode for this one
	# except for the first one
	if [[ $episode -ne $start_episode && $(( $episode % $episodes_per_dvd )) -ne 0 ]]; then
		echo
		echo "## Upcoming episode $episode is on the next DVD. Please insert the next DVD and press Enter."
		eject $dvd_device
		read
	fi

	# track number, will be 1 or 2
	track=$(( 2 - $episode % 2 ))
	# make a safe output file name by removing any "bad" characters
	title_safe=${title//[^a-zA-Z0-9+-._]/_} # replace problematic characters from title with '_'
	output_file="${title_safe}_S${season}E${episode}.mkv"

	# collect output files
	output_files+=("$output_file")

	# what if output file exists?
	if [[ -f $output_file ]]; then
		read -p "Output file '$output_file' already exist. Overwrite? [y/N] " overwrite
		if [[ "$overwrite" != 'y' ]]; then
			continue
		fi
	fi

	# actually start ripping
	echo
	printf "## Ripping \"%s\" season %d episode %d to '%s'" "$title" "$season" "$episode" "$output_file"
	echo

	handbrake_cmd="HandBrakeCLI $preset_option $lang_option -t $track -i $dvd_device"
	echo "Running: $handbrake_cmd -o $output_file"
	echo
	$handbrake_cmd -o "$output_file" || die "HandBrake failed"

done

# all done. report.
printf "## Done. Ripped %d episodes of \"%s\" season %d from %s.\n" $counter "$title" $season "$dvd_device"
echo "## Output files:"
for file in ${output_files[@]}; do
	printf "* %s\n" $file
done
