#!/usr/bin/python3

import requests
import xml.etree.ElementTree as etree
import sys

base_url = 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils'
esearch = base_url + '/esearch.fcgi'
efetch = base_url + '/efetch.fcgi'
db = 'nuccore'

# stitch together the query
term = '+AND+'.join(sys.argv[1:])

query = 'db=' + db + '&term=' + term

url = esearch + '?' + query

r = requests.get(url)

doc = etree.fromstring(r.text)

id_list = doc.findall('./IdList/Id')

for id in id_list:
    url = efetch + '?db=' + db + '&rettype=fasta&id=' + id.text
    r = requests.get(url)
    print(r.text.strip())


