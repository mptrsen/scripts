#!/bin/bash

# get the latest search results from NCBI PubMed for a list of queries,
# mail them to me

queries="transposable+element transposon nanopore"
smtp="smtp=smtp.mailbox.org"
fromaddr="malte.petersen@senckenberg.de"
toaddr="malte.petersen@senckenberg.de"
age=7
outdir="/var/tmp/pubmed-results"
baseurl='https://eutils.ncbi.nlm.nih.gov/entrez/eutils'
efetch="$baseurl/efetch.fcgi"
esearch="$baseurl/esearch.fcgi"

# create output directory
mkdir -p $outdir

# fetch search results for the last 7 days from pubmed
for query in $queries; do

	# fetch the search results to file
	file="$outdir/$query.txt"
	# get list of PMIDs
	ids=$(curl -s "$esearch" -d "db=pubmed&usehistory=y&datetype=pdat&reldate=$age&term=$query" | xpath -q -e '/eSearchResult/IdList/Id' | sed -e 's/<[^>]*>//g' | tr '\n' ',' | sed -e 's/,$//')
	# fetch search results
	curl -s "$efetch" -d "db=pubmed&rettype=abstract&retmode=text&id=$ids" > $file

	# make a pubmed URL from the PMID
	sed -i -e 's#PMID: #http://www.ncbi.nlm.nih.gov/pubmed/#' $file

	# mail that thing to me
	subject="PubMed results for '$query' in the last $age days"
	mailx -S "$smtp" -r $fromaddr -s "$subject" $toaddr < $file

done

