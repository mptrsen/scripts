#!/usr/bin/python3

"""
Randomly downsample a read library to a fraction of its original size
Input must be gzipped or bzipped FASTQ format
"""

from __future__ import division
import sys
import time
import random
import gzip
import bz2
import argparse

argparser = argparse.ArgumentParser()
argparser.add_argument("infile", type=str)
argparser.add_argument("outfile", type=str)
argparser.add_argument("-p", type=float, default=0.01, help="Percent of reads to be sampled (fraction of 1; default: 0.1)")
argparser.add_argument("-s", type=int, help="Set the random seed (integer)")
args = argparser.parse_args()

percent = float(args.p)

if not args.infile.endswith(".gz") and not args.infile.endswith(".bz2"): sys.exit("error: input file must be gzipped or bzipped fastq (ending in .gz or .bz2)")

if args.s:
	seed = int(args.s)
else:
	seed = int(time.time())

print("input file: %s" % args.infile)
print("output file: %s" % args.outfile)
print("sampling %.01f percent of the reads" % float(percent * 100))

random.seed(seed)

INPUT = ""

if args.infile.endswith(".gz"):
    try:
        INPUT = gzip.open(args.infile, 'rt')
    except:
        sys.exit("Fatal: could not open " + str(args.infile))

elif args.infile.endswith(".bz2"):
    try:
        INPUT = bz2.open(args.infile, 'rt')
    except:
        sys.exit("Fatal: could not open " + str(args.infile))

with gzip.open(args.outfile, 'wt') as OUTPUT:
    for line1 in INPUT:
        line2 = next(INPUT)
        line3 = next(INPUT)
        line4 = next(INPUT)
        if random.random() <= percent:
            OUTPUT.write(line1)
            OUTPUT.write(line2)
            OUTPUT.write(line3)
            OUTPUT.write(line4)
