#!/usr/bin/python

from __future__ import division
import sys
import os
import re
from decimal import *
import fastaParser
import fastatools

#print("Call: " + " ".join(sys.argv))

infiles = sys.argv[1:]

class baseCompo:
	"""Base composition parser"""
	def __init__(self):
		self.data = [ ]
		self.winsize = 50

	def gc_content(self, inf):
		self.parse_fasta(inf)

	def parse_fasta(self, f):
		db = fastatools.FastaFile(f)
		for hdr, seq in db.next_seq():
			gc_content = self.determine_gc(seq)
			of = open(os.path.normpath('/var/tmp/gc/' + hdr + '.csv'), 'w')
			of.write('pos,gc\n')
			for l in gc_content:
				of.write(','.join(str(x) for x in l) + '\n')
			of.close()
	
	def determine_gc(self, seq):
		gcs = [ ]
		for i in range(0, len(seq)-self.winsize, self.winsize):
			subs = seq[i:i+self.winsize]
			gs = subs.count('G')
			cs = subs.count('C')
			gcs.append([i+1, (gs / self.winsize) + (cs / self.winsize)])
		return(gcs)

compo = baseCompo()

for inf in infiles:
	compo.gc_content(inf)

sys.exit()
