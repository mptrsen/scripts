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
set -o pipefail

# need 3 arguments: annotation BED, genome assembly the annotation is based on, and Phobos result as BED file
if [ $# -ne 3 ]; then
	echo "Usage: $0 ANNOTATION_BED_FILE ASSEMBLY_FILE PHOBOS_BED_FILE"
	exit 1
fi

BED=$1
GENOME=$2
PHOBOS=$3

BASEN=$(basename $BED .bed)-noN
OUTDIR=results/genome-features
OUTFILE=$OUTDIR/$BASEN
LENGTHS=results/genome-features/$(basename $GENOME).lengths
OVERLAPNAME=results/genome-features/"$BASEN-phobos-overlapwith-maker-models-intergenic+introns+cds"
TEMPLATE="code/statistics-template.R"
NEXTRACTOR="code/fasta-gff-v1.0-dist/fasta-gff" # the most non-portable part of this script :/

if [ ! -f $BED    ]; then echo "No such file: $BED";    exit 1; fi
if [ ! -f $GENOME ]; then echo "No such file: $GENOME"; exit 1; fi
if [ ! -f $PHOBOS ]; then echo "No such file: $PHOBOS"; exit 1; fi

if [ ! -f $NEXTRACTOR ]; then echo "N-extractor not found: $NEXTRACTOR"; exit 1; fi

# get sequence lengths from the genome
echo "# getting sequence lengths..."
fastalength $GENOME | awk '{ print $2 "\t" $1 }' > $LENGTHS || exit 1

# calculate total size
echo "# calculating genome assembly size..."
GENOME_LENGTH=$(awk '{ s += $2 } END { print s }' $LENGTHS)

# use Christoph's tool to make a GFF of N positions
echo "# extracting Ns..."
$NEXTRACTOR $GENOME /dev/null $GENOME-Ns.gff
gff2bed < $GENOME-Ns.gff > $OUTFILE-Ns.bed

echo "# subtracting Ns from all features..."
bedtools subtract -a $BED -b $OUTFILE-Ns.bed | sortBed > $OUTFILE.bed

echo "# calculating total feature sizes..."
echo "feature	feature.size" > $OUTFILE-feature-sizes.txt
awk '{ s[$8] += $3 - $2 } END { for (f in s) { printf("%s\t%d\n", f, s[f]) } }' $OUTFILE.bed >> $OUTFILE-feature-sizes.txt

# get genes from the annotation
echo "# extracting genes..."
grep -P "\tgene\t" $OUTFILE.bed \
	| cut -f1-6,8-99 > $OUTFILE-genes.bed

# get intergenic regions
echo "# inferring intergenic regions..."
bedtools complement -i $OUTFILE-genes.bed -g $LENGTHS \
	| awk 'BEGIN { OFS="\t" } { print $1, $2, $3, $1 ":" $2 "-" $3, ".", ".", "intergenic" }' \
	> $OUTFILE-intergenic.bed 
awk '{ s += $3 - $2 } END { printf("intergenic\t%d\n", s) }' $OUTFILE-intergenic.bed >> $OUTFILE-feature-sizes.txt

# get exons and CDS
echo "# extracting CDS..."
awk '$8 == "CDS" || $8 == "exon"' $OUTFILE.bed \
	| bedtools merge -s \
	| awk 'BEGIN { OFS="\t" } { print $1, $2, $3, $1 ":" $2 "-" $3, ".", ".", "CDS" }' \
	> $OUTFILE-exons+cds-merged.bed
awk '$8 == "CDS"' $OUTFILE.bed \
	| cut -f1-6,8-99 \
	> $OUTFILE-cds.bed

echo "# extracting exons..."
awk '$8 == "exon"' $OUTFILE.bed \
	| cut -f1-6,8-99 \
	> $OUTFILE-exons.bed

# finally bring the files together to infer introns
echo "# inferring introns..."
cat $OUTFILE-exons.bed $OUTFILE-intergenic.bed \
	| cut -f1-7 \
	| sortBed \
	| bedtools complement -i - -g $LENGTHS \
	| awk 'BEGIN { OFS="\t" } { print $1, $2, $3, $1 ":" $2 "-" $3, ".", ".", "intron" }' \
	> $OUTFILE-introns.bed
awk '{ s += $3 - $2 } END { printf("intron\t%d\n", s) }' $OUTFILE-introns.bed >> $OUTFILE-feature-sizes.txt

echo "# combining all features..."
cat $OUTFILE-cds.bed $OUTFILE-intergenic.bed $OUTFILE-introns.bed \
	| cut -f1-7 \
	| sortBed \
	> $OUTFILE-cds+introns+intergenic.bed

echo "# intersecting with Phobos result..."
bedtools intersect -a $PHOBOS -b $OUTFILE-cds+introns+intergenic.bed -wo \
	| cut -f1-3,7,9,11-12,15-17 \
	> ${OVERLAPNAME}.bed

# convert the BED file to a sensible table for R to read in
echo "# formatting table for statistics..."
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
	-e "s#FEATURELENGTHFILE#$OUTFILE-feature-sizes.txt#" \
	$TEMPLATE > $OUTDIR/statistics-${BASEN}.R 
	R --no-save --slave < $OUTDIR/statistics-${BASEN}.R > $OUTDIR/statistics-${BASEN}.txt
