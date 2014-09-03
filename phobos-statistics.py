#!/usr/bin/python

from __future__ import division
import sys
import re
import fastaParser

print "Call: " + " ".join(sys.argv)

if (len(sys.argv) != 3):
	sys.exit("Need two arguments!")

phobosfile = sys.argv[-2]
genomefile = sys.argv[-1]

# regexes
re_seq             = re.compile("^>(\S+_\d+)")
re_nucl            = re.compile("^\s*\S+nucleotide\s+(\d+) :\s+(\d+)")
re_acgtu           = re.compile("^number of ACGTU characters: (\d+)")
re_split           = re.compile("\s+\|\s+")
re_non_nucleotides = re.compile("([^A-Za-z])")

# data structure 
data_for = { }
scaffold = ""
fields = [ ]

# parse phobos file, store everything in multi-dim structure
fh = open(phobosfile)

line = fh.readline()

if not re.match("# Results computed with:", line):
	raise ValueError, "Not a Phobos file"

for line in fh:
	# is this an "input file name" line?
	m = re.match("^# Input file name:\s+(\S+)$", line)
	if m: 
		pass

	# is this a ">scaffold" line?
	m = re_seq.match(line)
	if m:
		scaffold = m.group(1)
		data_for[scaffold] = [ ]
		print "matched: " + scaffold
		next

	# is this a "nucleotide" line?
	# if so, add this repeat to the data structure
	m = re_nucl.match(line)
	if m: 
		fields = re_split.split(line)
		if fields:
			data_for[scaffold].append(
				{
					'start': int(m.group(1)),
					'end': int(m.group(2)),
					'unit': fields[-1][5:].rstrip()
				}
			)
		next

fh.close()

winsize = 50

count_a = 0
count_t = 0
count_c = 0
count_g = 0

fh = open(genomefile)

while True:
	try:
		for hdr, seq in fastaParser.parse(fh):
			print ">%s" % hdr
			for repeat in data_for[hdr]:
				start = repeat['start']
				end   = repeat['end']

				
				gc = 0.0

				for i in range(start, end-winsize):
					subseq = seq[i:i+winsize]
					count_a = subseq.count('A')
					count_t = subseq.count('T')
					count_c = subseq.count('C')
					count_g = subseq.count('G')
					#--------------------------------------------------
					# print "perc A: %.2f" % (count_a / winsize)
					# print "perc T: %.2f" % (count_t / winsize)
					# print "perc C: %.2f" % (count_c / winsize)
					# print "perc G: %.2f" % (count_g / winsize)
					#-------------------------------------------------- 

				
				print "repeat [%d-%d]: range %d to %d: GC: %f" % (start, end, start, end, (count_g + count_c) / winsize)
	except ValueError: sys.exit("Fatal: Not a Fasta file?")
