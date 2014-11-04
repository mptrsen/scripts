#!/usr/bin/python

from __future__ import division
import sys
import os
import re
import fastatools
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('--outdir', type=str, default=os.getcwd(), help="specify output directory")
parser.add_argument('--winsize', type=int, default=50, help="specify sliding window size")
parser.add_argument('infile', type=str, nargs='+', help="specify input file")
args = parser.parse_args()

outdir = args.outdir
infiles = args.infile

def main():
	make_dir(outdir)
	for inf in infiles:
		print("parsing " + inf)
		parse_fasta(inf)

def parse_fasta(f):
	db = fastatools.FastaFile(f)
	for hdr, seq in db.next_seq():
		gc_content = determine_gc(seq)
		if gc_content:
			of = open(os.path.join(outdir, hdr + '.csv'), 'w')
			of.write('pos,percG,percC,percA,percT\n')
			for l in gc_content:
				of.write(','.join(str(x) for x in l) + '\n')
			of.close()
		else: pass

def determine_gc(seq):
	gcs = [ ]
	winsize = args.winsize
	for i in range(0, len(seq)-winsize, winsize):
		subs = seq[i:i+winsize]
		Gs = subs.count('G')
		Cs = subs.count('C')
		As = subs.count('A')
		Ts = subs.count('T')
		gcs.append([i+1, Gs/winsize, Cs/winsize, As/winsize, Ts/winsize])
	return(gcs)

def make_dir(dir):
	if os.access(dir, os.F_OK):
		pass
	else:
		try:
			os.makedirs(dir)
		except:
			raise IOError("Could not create dir " + str(dir))

if __name__ == '__main__':
	main()
