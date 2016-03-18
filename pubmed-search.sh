#!/bin/bash

# get the latest search results from NCBI PubMed for a list of queries,
# mail them to me

QUERIES="transposable+element transposon"
SMTP="smtp=smtp.uni-bonn.de"
FROMADDR="mptrsen@uni-bonn.de"
TOADDR="mptrsen@uni-bonn.de"
AGE=7
OUTDIR="/var/tmp/pubmed-results"
EFETCH="/home/mpetersen/local/bin/efetch"
ESEARCH="/home/mpetersen/local/bin/esearch"

# create output directory
mkdir -p $OUTDIR

# fetch search results for the last 7 days from pubmed
for QUERY in $QUERIES; do

	# fetch the search results to file
	FILE="$OUTDIR/$QUERY.txt"
	$ESEARCH -db pubmed -query "$QUERY" -days $AGE | $EFETCH > $FILE 2>&1

	# make a pubmed URL from the PMID
	sed -i -e 's#PMID: #http://www.ncbi.nlm.nih.gov/pubmed/#' $FILE

	# mail that thing to me
	SUBJECT="PubMed results for '$QUERY' in the last $AGE days"
	mailx -S "$SMTP" -r $FROMADDR -s "$SUBJECT" $TOADDR < $FILE

done

