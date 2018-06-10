#!/usr/bin/python3

import requests
import xml.etree.ElementTree as etree
import argparse
import sys

# parse command line arguments
parser = argparse.ArgumentParser()
parser.add_argument('-m', '--max',  action = 'store', dest = 'retmax', type = int,  default = 100,       help = 'Maximum number of entries. Default: 100')
parser.add_argument('-d', '--db',   action = 'store', dest = 'db',     type = str,  default = 'nuccore', help = 'Database to search. Default: nuccore')
parser.add_argument('-t', '--type', action = 'store', dest = 'rettype', type = str, default = 'fasta',   help = 'Return type. Default: fasta')
parser.add_argument('search_terms', nargs = '+',      help = 'Search terms')
args = parser.parse_args()

# some variables
base_url = 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils'
esearch  = base_url + '/esearch.fcgi'
efetch   = base_url + '/efetch.fcgi'
db       = args.db
rettype  = args.rettype
retmax   = args.retmax
term     = '+'.join(args.terms)

sys.stderr.write("Searching for: %s\n" % ' '.join(args.terms))

# esearch request
url   = "%s?db=%s&retmax=%d&term=%s" % (esearch, db, retmax, term)
sys.stderr.write("Request: %s\n" % url)
r = requests.get(url)

# parse XML
doc     = etree.fromstring(r.text)
IdList  = doc.findall('./IdList/Id')

# exit now if nothing returned
if len(IdList) == 0:
    sys.stderr.write("Nothing found.\n")
    sys.exit(1)

# fetch fasta for each id: make comma-separated id list
ids = ','.join( [ Id.text for Id in IdList ] )

# efetch them all in one go and print
url = "%s?db=%s&rettype=%s&id=%s" % (efetch, db, rettype, ids)
sys.stderr.write("Request: %s\n" % url)
r   = requests.get(url)
print(r.text.replace("\n\n", "\n").strip())
