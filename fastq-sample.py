#!/usr/bin/python3

"""
Randomly downsample a read library to a fraction of its original size
Input must be gzipped FASTQ format
"""

from __future__ import division
import sys
import time
import random
import gzip
import argparse

argparser = argparse.ArgumentParser()
argparser.add_argument("infile", type=str)
argparser.add_argument("outfile", type=str)
argparser.add_argument("-p", type=float, default=0.01, help="Percent of reads to be sampled (fraction of 1; default: 0.1)")
argparser.add_argument("-s", type=int, help="Set the random seed (integer)")
args = argparser.parse_args()

percent = 0.1

if not args.infile.endswith(".gz"): sys.exit("error: input file must be gzipped fastq")

if args.p: percent = float(args.p)

if args.s:
	seed = int(args.s)
else:
	seed = int(time.time())

print("input file: %s" % args.infile)
print("output file: %s" % args.outfile)
print("sampling %.01f percent of the reads" % float(percent * 100))

random.seed(seed)

with gzip.open(args.infile, 'rt') as input:
    with gzip.open(args.outfile, 'wt') as output:
        for line1 in input:
            line2 = next(input)
            line3 = next(input)
            line4 = next(input)
            if random.random() <= percent:
                output.write(line1)
                output.write(line2)
                output.write(line3)
                output.write(line4)
