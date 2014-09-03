#!/usr/bin/python

from __future__ import division
import sys
import re
from decimal import *
import fastaParser

#print("Call: " + " ".join(sys.argv))

inf = sys.argv[-1]

class baseCompo:
	"""Base composition parser"""
	def __init__(self):
		self.data = [ ]
		self.winsize = 50

	def gc_content(self, inf):
		self.parse_fasta(inf)
		
	def parse_fasta(self, f):
		print 'pos,gc'
		fh = open(f)
		for hdr, seq in fastaParser.parse(fh):
			self.determine_gc(seq)
			sys.exit()
		fh.close()
	
	def determine_gc(self, seq):
		for i in range(0, len(seq)-self.winsize, self.winsize):
			subs = seq[i:i+self.winsize]
			gs = subs.count('G')
			cs = subs.count('C')
			print '%d,%.4f' % (i+1, (Decimal(gs) / self.winsize) + (Decimal(cs) / self.winsize))

compo = baseCompo()

compo.gc_content(inf)

sys.exit()
