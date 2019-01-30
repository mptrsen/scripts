#!/bin/bash

# Copyright 2018, Malte Petersen <mptrsen@uni-bonn.de>
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

set -e
set -o pipefail

function die {
	echo "Fatal: $@"
	exit 1
}

while getopts "n:" option; do
        case "$option" in
                n)
                        num_threads=$OPTARG
                        ;;
        esac
        # remove option from parameter list
        shift $((OPTIND-1))
done
num_threads=${num_threads:-1}

if [[ $# -lt 1 ]]; then die "argument required"; fi

blastx='/home/mpetersen/local/bin/blastx'
blastdbcmd='/home/mpetersen/local/bin/blastdbcmd'
nr='/gendata_aj/mpetersen/analyses/data/db/nr/2018-10-22/nr'
perl='/usr/bin/perl'
fastagrep='/home/mpetersen/scripts/fastagrep.pl'
keywordsfile='/gendata_aj/mpetersen/analyses/doc/keywords.txt'

if [[ ! -x $perl ]]; then perl='perl'; fi
if [[ ! -x $blastx ]]; then blastx='blastx'; fi
if [[ ! -x $blastdbcmd ]]; then blastdbcmd='blastdbcmd'; fi
if [[ ! -f ${nr}.pal ]]; then echo "Error: BLAST database does not exist at $nr"; exit 1; fi

# repeat library, first argument
library="${1:=$library}"
echo "## Input library: $library"
echo "$(grep -c '>' $library) sequences"
echo "$(grep -c '#Unknown' $library) unknown elements"

# blast output file, second argument
blastoutfile="${2:-${library}.blast}"

# search in NCBI nr database
echo "## Searching..."
if [[ ! -s $blastoutfile ]]; then
	echo $blastx -db $nr -query "$library" -num_threads $num_threads -outfmt 7 -out "$blastoutfile"
	$blastx -db $nr -query "$library" -num_threads $num_threads -outfmt 7 -out "$blastoutfile"
else
	echo "BLAST output file $blastoutfile exists, skipping search"
fi
echo "$(wc -l < $blastoutfile) hits"

# get all unknown hits
echo "## Filtering for unknown elements"
grep -v '^#' $blastoutfile \
	| grep '#Unknown' \
	| cut -f 2 \
	| sort \
	| uniq \
	> unknown-hits.txt
echo "$(wc -l < unknown-hits.txt) hits for unknown elements"

# need the sequence title to decide whether these might be TEs or not
echo "## Fetching sequence titles from database"
echo $blastdbcmd -db $nr -entry_batch unknown-hits.txt  -outfmt "%a	%t" -out unknown-hits2titles.txt
$blastdbcmd -db $nr -entry_batch unknown-hits.txt  -outfmt "%a	%t" -out unknown-hits2titles.txt
echo "$(wc -l < unknown-hits2titles.txt) titles"

# filter hits2titles according to keywords
echo "## Filtering for keywords"
grep -f $keywordsfile unknown-hits2titles.txt \
	| cut -f 1 \
	| sort \
	| uniq \
	> unknown-keep-these-accessions.txt
echo "$(wc -l < unknown-keep-these-accessions.txt) remaining"

# get the corresponding TE headers from the blast outfile, for unknown TEs
echo "## Getting headers"
grep -v '^#' $blastoutfile \
	| grep -F -f unknown-keep-these-accessions.txt \
	| grep '#Unknown' \
	| cut -f 1 \
	| sort \
	| uniq \
	> unknown-keep-these-headers.txt
echo "$(wc -l < unknown-keep-these-headers.txt) headers"

# also get all non-unknown headers from the library
echo "## Getting headers from known elements"
grep '>' $library \
	| grep -v '#Unknown' \
	| sed -e 's/^>//' \
	| sed -e 's/ .\+$//' \
	> known-keep-these-headers.txt
echo "$(wc -l < known-keep-these-headers.txt) known sequences"

# put them both together, add \b to the end
echo "## Putting them both together and adding word boundaries"
cat unknown-keep-these-headers.txt known-keep-these-headers.txt \
	| sed -e 's/$/\\b/' \
	> keep-these-headers.txt
echo "$(wc -l < keep-these-headers.txt) total"

# keep these from the repeat library, remove the rest
echo "## Filtering repeat library"
$perl $fastagrep -f keep-these-headers.txt $library > filtered-library.fa
echo "$(grep -c '>' filtered-library.fa) sequences in filtered library"

echo "## Done."
