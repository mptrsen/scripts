#!/usr/bin/python

class FastaFile:
	def __init__(self, inf):
		self.filename = inf
		self.fh = open(self.filename)
	
	def next_seq(self):
		return self.parse(self.fh)

	def parse(self, handle):
		# test whether the file starts with a > (i.e., is a valid fasta file)
		while True:
			line = handle.readline()
			if line == "":
				return
			if line[0] != ">":
				raise ValueError("Invalid Fasta file format")  # premature end of file
			else:
				break
		
		while True:
			if line[0] != ">":
				raise ValueError("Records in Fasta files should start with '>' character")

			# remove '>' and trailing whitespace
			header = line[1:].rstrip()
			lines = []

			# a sequence, keep reading lines until you reach the next '>'
			line = handle.readline()
			while True: 
				if not line:
					break  # eof reached
				if line[0] == ">":
					break
				lines.append(line.rstrip())
				line = handle.readline()

			yield header, "".join(lines)

			if not line:
				return
		
		assert False, "Error: Should not reach this line!"

