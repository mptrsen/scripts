#!/bin/bash
# Author: Malte Petersen
# Run FastQC on an input file

set -e

PREFIX="/var/data/graduateschool"
OUTPUT_PREFIX="$PREFIX/pool/fastqc"
FASTQC="perl $PREFIX/tools/FastQC/fastqc --threads=4 --quiet --outdir=$OUTPUT_PREFIX"
echo "# $(date --rfc-3339=seconds) Started FastQC on $1"
$FASTQC $1
echo "# $(date --rfc-3339=seconds) Completed FastQC on $1"
