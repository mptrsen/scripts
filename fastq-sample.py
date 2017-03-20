#!/usr/bin/python3

# Randomly downsample a read library to a fraction of its original size
# Input must be gzipped FASTQ format
from __future__ import division
import sys
import random
import gzip
import argparse

argparser = argparse.ArgumentParser()
argparser.add_argument("infile", type=str)
argparser.add_argument("outfile", type=str)
argparser.add_argument("-p", type=float, default=0.01, help="Percent of reads to be sampled (fraction of 1; default: 0.1)")
argparser.add_argument("-s", type=int, default=100, help="Set the random seed (integer)")
args = argparser.parse_args()

if not args.infile.endswith(".gz"): sys.exit("error: input file must be gzipped fastq")
if args.p: percent = float(args.p)

with gzip.open(args.infile, 'rt') as input:
    with gzip.open(args.outfile, 'wt') as output:
        for line1 in input:
            print(line1.strip())
            line2 = next(input)
            line3 = next(input)
            line4 = next(input)
            if random.random() <= percent:
                output.write(line1)
                output.write(line2)
                output.write(line3)
                output.write(line4)
