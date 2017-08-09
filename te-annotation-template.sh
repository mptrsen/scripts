#!/bin/bash
#$ -cwd
#$ -j n
#$ -S /bin/bash
#$ -M mptrsen@uni-bonn.de
#$ -m be
#$ -N te-SPECIES_NAME

# make pipelines fail if a component fails 
set -o pipefail
# exit if anything fails
set -e

####################################
# Variables that affect everything #
####################################

SPECIES='SPECIES_NAME'
INPUTFILE='GENOMEFILE'
CLADE="Metazoa" # RepBase will be included using this as taxonomy query
LIBRARY_FILE="PATH_TO_REPEAT_LIBRARY" # will look for library in RepeatModeler output directory if this does not exist
PREFIX='/share/pool/malte/analyses/results/te-pipeline' # used to compose output directory by appending SPECIES
NCPU=${NSLOTS:=1}
RUN_MODELER=1
RUN_MASKER=1
MAKE_LANDSCAPE=1
DRY_RUN=0

# because of a bug in both RModeler and RMasker, we must halve the number of threads
let NCPU_RMBLAST=$NCPU/2
if [[ $NCPU_RMBLAST -lt 1 ]]; then
	die "Fatal: RMBLAST requires at least 2 cores, but you gave this only $NCPU"
fi

####################################
# Program paths                    #
####################################

PERL=/opt/perl/bin/perl
RMASKER_DIR=/share/scientific_bin/RepeatMasker/4.0.7
RMODELER_DIR=/share/scientific_bin/RepeatModeler/open-1.0.10bugfix
#FASTASOFTMASK=/share/scientific_bin/exonerate/2.2/bin/fastasoftmask # no longer needed
LANDSCAPEPARSER=/home/mpetersen/scripts/parse-repeatmasker-landscapes-to-table.pl

####################################
# General functions                #
####################################

function die {
	echo "$@"
	exit 1
}

function test-if-programs-exist {
	for path in $@; do
		# die if not executable
		if [[ ! -x "$path" ]]; then
			die "Fatal: $path not found or not executable"
		fi
		echo "## - Found '$path'"
	done
}

function run-command {
	echo "Running: $@" >&2
	if [[ $DRY_RUN -ne 1 ]]; then
		"$@" || return 1
	fi
	return 0
}

####################################
# The RepeatModeler part           #
####################################

function run-modeler {
	if [[ $# -ne 1 ]]; then 
		echo "Usage: run-modeler GENOME"
		exit 1
	fi
	GENOME="$1"
	DB="$SPECIES-rm"
	GENOME_BASENAME=$(basename "$GENOME")

	# create working directory and chdir into it
	MODELER_WORKDIR="$PREFIX/$SPECIES/repeatmodeler"
	mkdir -p "$MODELER_WORKDIR" || die "Fatal: Could not make output directory"
	cd "$MODELER_WORKDIR"

	# create soft link to input genome file
	echo "## linking input file '$GENOME'"
	if [[ ! -f "$GENOME" ]]; then die "Fatal: $GENOME does not exist"; fi
	if [[ -L "$GENOME_BASENAME" ]]; then rm "$GENOME_BASENAME"; fi
	ln -s "$GENOME"

	echo "## RepeatModeler started $(date --rfc-3339=seconds)"

	# create database first
	run-command "$RMODELER_DIR/BuildDatabase" -name "$DB" "$GENOME_BASENAME" || return 1
	# run the beast
	run-command "$RMODELER_DIR/RepeatModeler" -pa $NCPU_RMBLAST -engine ncbi -database "$DB" || return 1

	echo "## RepeatModeler done $(date --rfc-3339=seconds)"
}

####################################
# The RepeatMasker part           #
####################################

function run-masker {
	if [[ $# -ne 2 ]]; then
		echo "Usage: run-masker LIBRARY GENOME"
		exit 1
	fi
	LIB="$1"
	GENOME="$2"
	GENOME_BASENAME=$(basename "$GENOME")
	COMBINED_LIB="repbase-$CLADE+$SPECIES.fa"

	# data
	MASKER_WORKDIR="$PREFIX/$SPECIES/repeatmasker"

	echo "## creating output directory '$MASKER_WORKDIR'"
	mkdir -p "$MASKER_WORKDIR" || return 1
	cd "$MASKER_WORKDIR"

	echo "## linking input file '$GENOME'"
	if test -L "$GENOME_BASENAME"; then rm "$GENOME_BASENAME"; fi
	ln -s "$GENOME" || return 1

	echo "## Combining $CLADE RepBase and species-specific repeat library into '$COMBINED_LIB'"
	run-command "$RMASKER_DIR/util/queryRepeatDatabase.pl" --clade --species "$CLADE" > "$COMBINED_LIB" || return 1
	cat $LIB >> $COMBINED_LIB

	echo "## RepeatMasker started on '$GENOME_BASENAME' $(date --rfc-3339=seconds)"
	run-command $PERL "$RMASKER_DIR/RepeatMasker" -engine ncbi -par $NCPU_RMBLAST -a -xsmall -gff -lib "$COMBINED_LIB" "$GENOME_BASENAME" || return 1

	echo "## RepeatMasker done $(date --rfc-3339=seconds)"
}

####################################
# Post-processing and landscape    #
####################################

function post-process {
	if [[ $# -ne 1 ]]; then
		echo "Usage: post-process RMASKER_OUTPUT_CATFILE"
		exit 1
	fi

	RMASKER_OUTPUT_CATFILE="$1"
	RMASKER_OUTPUT_OUTFILE="${RMASKER_OUTPUT_CATFILE%.cat.gz}.out"
	RMASKER_OUTDIR=$(dirname "$1")
	DIV="$SPECIES.div"
	LANDSCAPE="$SPECIES-repeat-landscape.html"
	LANDSCAPE_TABLE="$SPECIES-repeat-landscape-data.txt"
	SUMMARY_TABLE="$SPECIES-summary.tbl"
	GENOME_BASENAME=$(basename "$INPUTFILE")

	# this is no longer needed: Rmasker can output softmasked sequences with the -xsmall option
	#echo "## turning the hard mask into a soft mask on '$RMASKER_OUTDIR/$GENOME_BASENAME'"
	#run-command "$FASTASOFTMASK" -m "$RMASKER_OUTDIR/$GENOME_BASENAME" -u "$RMASKER_OUTDIR/$GENOME_BASENAME.masked" > "$RMASKER_OUTDIR/$GENOME_BASENAME.softmasked"

	SUMMARY_DIR="$PREFIX/$SPECIES/summary"
	mkdir -p "$SUMMARY_DIR" || return 1
	cd "$SUMMARY_DIR"

	echo "## converting output file to GFF3 format"
	run-command $PERL "$RMASKER_DIR/util/rmOutToGFF3.pl" "$RMASKER_OUTPUT_OUTFILE" > "$RMASKER_OUTPUT_OUTFILE.gff3" || return 1

	echo "## calculating divergence statistics into '$DIV'"
	run-command $PERL "$RMASKER_DIR/util/calcDivergenceFromAlign.pl" -s "$DIV" "$RMASKER_OUTPUT_CATFILE" || return 1

	echo "## creating repeat landscape into '$LANDSCAPE'"
	run-command $PERL "$RMASKER_DIR/util/createRepeatLandscape.pl" -div "$DIV" > "$LANDSCAPE" || return 1

	echo "## parsing landscape table"
	run-command $PERL "$LANDSCAPEPARSER" "$LANDSCAPE" > "$LANDSCAPE_TABLE" || return 1

	echo "## Generating species-specific summary"
	run-command $PERL "$RMASKER_DIR/util/buildSummary.pl" -species "$SPECIES" -useAbsoluteGenomeSize "$RMASKER_OUTPUT_OUTFILE" > "$SUMMARY_TABLE"
}


####################################
# Putting it all together          #
####################################

echo "## BEGIN $(date --rfc-3339=seconds)"

if [[ $DRY_RUN -ne 0 ]]; then
	echo "## This is a dry run: commands will be echoed on standard error but not actually executed"
fi

echo "## Testing dependencies..."
test-if-programs-exist $RMODELER_DIR/BuildDatabase $RMODELER_DIR/RepeatModeler $RMASKER_DIR/RepeatMasker

OUTPUT_DIRECTORY="$PREFIX/$SPECIES"

# uncompress input file if gzipped
if [[ "$INPUTFILE" =~ \.gz$ ]]; then
	echo "## uncompressing input file"
	gunzip "$INPUTFILE" || die "Fatal: Could not uncompress gzipped genome file"
	INPUTFILE=${INPUTFILE%.gz} # remove .gz suffix
fi

# run RepeatModeler if requested
if [[ $RUN_MODELER -ne 0 ]]; then
	run-modeler "$INPUTFILE" || die "Fatal: Running RepeatModeler failed"
fi

# identify repeat library file
if [[ -f $LIBRARY_FILE || $DRY_RUN -ne 0 ]]; then
	echo "## Using specified repeat library $LIBRARY_FILE"
	REPEAT_LIBRARY=$LIBRARY_FILE
else
	echo "## Repeat library unspecified or not found, searching in output directory $OUTPUT_DIRECTORY"
	REPEAT_LIBRARY=$(find "$OUTPUT_DIRECTORY/repeatmodeler" -maxdepth 2 -name "*.classified" -or -name '*-rm-families.fa')
	test -f "$REPEAT_LIBRARY" || die "Fatal: Repeat library not found" # exit if unset
fi
echo "## Repeat library: '$REPEAT_LIBRARY'"

# run RepeatMasker if requested
if [[ $RUN_MASKER -ne 0 ]]; then
	run-masker "$REPEAT_LIBRARY" "$INPUTFILE" || die "Fatal: Running RepeatMasker failed"
	MASKER_OUTPUT="$OUTPUT_DIRECTORY/repeatmasker/$(basename "$INPUTFILE").cat.gz"
	MASKER_TABLE="$OUTPUT_DIRECTORY/repeatmasker/$(basename "$INPUTFILE").tbl"
	echo "## RepeatMasker output: '$MASKER_OUTPUT'"
fi

# post-process and generate landscape data table if requested
if [[ "$MAKE_LANDSCAPE" -ne 0 ]]; then
	post-process "$MASKER_OUTPUT" || die
fi

echo "## Summary table: '$MASKER_TABLE'"
cat "$MASKER_TABLE"

echo "## END $(date --rfc-3339=seconds)"
