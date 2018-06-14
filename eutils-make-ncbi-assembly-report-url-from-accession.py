#!/usr/bin/python

import xml.etree.ElementTree as etree
import requests
import sys
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('term', help = 'Search terms. Can be string or accession number')
args = parser.parse_args()

term = '+'.join([args.term])

base_url = 'ftp://ftp.ncbi.nlm.nih.gov/genomes/all'

gca = [ ]
is_accession = 0
url = ''

if term[0:1] == 'GC':
    is_accession = 1
    url = url_from_accession(base_url, term)

def url_from_accession(base_url, accession):
    gca = accession.split('_', 2)
    nums = gca[1]
    gca = gca[0]

    triplets = [ ]
    triplets.append( nums[0:3] )
    triplets.append( nums[3:6] )
    triplets.append( nums[6:9] )

    url = base_url + '/%s/%03d/%03d/%03d/%s' % (gca, int(triplets[0]),  int(triplets[1]),  int(triplets[2]), accession )
    return(url)

# so we have the URL, but we still need the assembly name!
# use efetch/esummary for that.

eutils_url = 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils'
esearch  = eutils_url + '/esearch.fcgi'
esummary = eutils_url + '/esummary.fcgi'

esearch_url = "%s?db=genome&term=%s" % ( esearch, term )
r = requests.get(esearch_url)

# parse XML
doc     = etree.fromstring(r.text)
IdList  = doc.findall('./IdList/Id')

# exit now if nothing returned
if len(IdList) == 0:
    sys.stderr.write("Nothing found.\n")
    sys.exit(1)

# fetch fasta for each id: make comma-separated id list
ids = ','.join( [ Id.text for Id in IdList ] )

# get the summary for that ID
esummary_url = "%s?db=genome&id=%s" % ( esummary, ids )
r = requests.get(esummary_url)

# parse XML
doc     = etree.fromstring(r.text)
name  = doc.findall("./DocSum/Item[@Name='Assembly_Name']")[0]
name = name.text.replace(' ', '_')
accession  = doc.findall("./DocSum/Item[@Name='Assembly_Accession']")[0].text
url = "%s_%s/%s_%s_assembly_stats.txt" % (url_from_accession(base_url, accession), name, accession, name)

print(url)
