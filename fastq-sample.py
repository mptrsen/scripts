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

if sys.version_info[0] != 3 or sys.version_info[1] < 3:
    sys.exit("Version mismatch: Python 3.3 or later required. You have %d.%d" % ( sys.version_info[0], sys.version_info[1] ) )

argparser = argparse.ArgumentParser()
argparser.add_argument("infile", type=str)
argparser.add_argument("outfile", type=str)
argparser.add_argument("-p", "--percent",     type=float, default=0.01, help="Percent of records to be sampled (fraction of 1; default: 0.1)")
argparser.add_argument("-s", "--seed",        type=int, help="Set the random seed (integer)")
argparser.add_argument("-n", "--max-records", type=int, help="Maximum number of records to be sampled")
args = argparser.parse_args()

percent = float(args.percent)

if not args.infile.endswith(".gz") and not args.infile.endswith(".bz2"):
    sys.exit("error: input file must be gzipped or bzipped fastq (ending in .gz or .bz2)")

seed        = args.seed if args.seed else int(time.time())
max_records = args.max_records if args.max_records else float("inf")

print("input file: %s" % args.infile)
print("output file: %s" % args.outfile)
print("sampling %.01f percent of the reads" % float(percent * 100))

random.seed(seed)

INPUT = ""

if args.infile.endswith(".gz"):
    try:
        # io.TextIOWrapper required for backwards compatibility with Python 3.2
        INPUT = gzip.open(args.infile, 'rt')
    except Exception as e:
        sys.exit("Fatal: could not open " + str(args.infile) + ": %s" % e)

elif args.infile.endswith(".bz2"):
    try:
        # io.TextIOWrapper required for backwards compatibility with Python 3.2
        INPUT = bz2.open(args.infile, 'rt')
    except Exception as e:
        sys.exit("Fatal: could not open " + str(args.infile) + ": %s" % e)

n_written = 0

with gzip.open(args.outfile, 'wt') as OUTPUT:
    for line1 in INPUT:
        line2 = next(INPUT)
        line3 = next(INPUT)
        line4 = next(INPUT)
        if random.random() <= percent:
            OUTPUT.write(str(line1))
            OUTPUT.write(str(line2))
            OUTPUT.write(str(line3))
            OUTPUT.write(str(line4))
            n_written += 1
            if n_written >= max_records: break
                

print("Wrote %d records" % n_written)
