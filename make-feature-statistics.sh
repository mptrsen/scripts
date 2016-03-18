#!/bin/bash

# Copyright 2015, Malte Petersen <mptrsen@uni-bonn.de>
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

# need 3 arguments: annotation BED, genome assembly the annotation is based on, and Phobos result as BED file
if [ $# -ne 3 ]; then
	echo "Usage: $0 ANNOTATION_BED_FILE ASSEMBLY_FILE PHOBOS_BED_FILE"
	exit 1
fi

BED=$1
GENOME=$2
PHOBOS=$3

if [ ! -f $BED    ]; then echo "No such file: $BED"; exit 1; fi
if [ ! -f $GENOME ]; then echo "No such file: $GENOME"; exit 1; fi
if [ ! -f $PHOBOS ]; then echo "No such file: $PHOBOS"; exit 1; fi

BASEN=$(basename $BED .bed)
LENGTHS=$(basename $GENOME).lengths
OVERLAPNAME="$BASEN-phobos-overlapwith-maker-models-intergenic+introns+exons"
TEMPLATE="/home/mpetersen/data/repeats/phobos-analyses/i5k/1-51ms12mm5id5imp/statistics/statistics-template.R"

# get sequence lengths from the genome
echo "# getting sequence lengths..."
fastalength $GENOME | awk '{ print $2 "\t" $1 }' > $LENGTHS || exit 1

# calculate total size
echo "# calculating genome assembly size..."
GENOME_LENGTH=$(awk '{ s += $2 } END { print s }' $LENGTHS)

# get genes from the annotation
echo "# extracting genes..."
grep -P "\tgene\t" $BED \
	| cut -f1-6,8-99 > $BASEN-genes.bed

# get intergenic regions
echo "# inferring intergenic regions..."
bedtools complement -i $BASEN-genes.bed -g $LENGTHS \
	| awk 'BEGIN { OFS="\t" } { print $1, $2, $3, $1 ":" $2 "-" $3, ".", ".", "intergenic" }' \
	> $BASEN-intergenic.bed 

# get exons and CDS
echo "# extracting exons and CDS..."
grep '\(exon\|CDS\)' $BED \
	| bedtools merge -s \
	| awk 'BEGIN { OFS="\t" } { print $1, $2, $3, $1 ":" $2 "-" $3, ".", ".", "CDS" }' \
	> $BASEN-exons+cds-merged.bed
grep 'CDS' $BED \
	| cut -f1-6,8-99 \
	> $BASEN-cds.bed
awk '$8 == "exon"' $BED \
	| cut -f1-6,8-99 \
	> $BASEN-exons.bed

# finally bring the files together to infer introns
echo "# inferring introns..."
cat $BASEN-exons.bed $BASEN-intergenic.bed \
	| cut -f1-7 \
	| sort-bed - \
	| bedtools complement -i - -g $LENGTHS \
	| awk 'BEGIN { OFS="\t" } { print $1, $2, $3, $1 ":" $2 "-" $3, ".", ".", "intron" }' \
	> $BASEN-introns.bed

echo "# combining all features..."
cat $BASEN-exons.bed $BASEN-intergenic.bed $BASEN-introns.bed \
	| cut -f1-7 \
	| sort-bed - \
	> $BASEN-exons+introns+intergenic.bed

echo "# intersecting with Phobos result..."
bedtools intersect -a $PHOBOS -b $BASEN-exons+introns+intergenic.bed -wo \
	| cut -f1-3,7,9,11-12,15-17 \
	> ${OVERLAPNAME}.bed

# convert the BED file to a sensible table for R to read in
echo "# generating table for statistics..."
echo "query.sequence	repeat.start	repeat.end	repeat.type	unit.size	repeat.number	perfection	unit	feature.start	feature.end	feature.strand	feature	overlap" \
	> $OVERLAPNAME-table-for-R.tsv
sed -e 's/Name="repeat_region [0-9]\+-[0-9]\+ unit_size //' \
    -e 's/"//g' \
    -e 's/ [^0-9]\+ /	/g' \
    ${OVERLAPNAME}.bed \
		>> $OVERLAPNAME-table-for-R.tsv

# customize the R script and run it to generate plots and statistics
echo "# making plots and calculating statistics..."
sed -e "s#INPUTFILE#$OVERLAPNAME-table-for-R.tsv#" \
	-e "s/SIZE/$GENOME_LENGTH/" \
	$TEMPLATE \
	| R --no-save --slave > statistics-${BASEN}.txt
