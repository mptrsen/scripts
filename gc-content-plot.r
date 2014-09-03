#!/usr/bin/Rscript

library('seqinr')

infile = commandArgs(trailingOnly = T)[-1]

winsize = 50

genome = read.fasta(file = infile)

for (sequence in genome) {

	starts = seq(1, length(sequence) - winsize, by = winsize)
	n = length(starts)
	chunkGCs = numeric(n)

	for (i in 1:n) {
		chunk = sequence[starts[i]:(starts[i]+winsize)]
		chunkGC = GC(chunk)
		chunkGCs[i] = chunkGC
	}
	pdf(file = paste('/var/tmp/gc/plot-', attr(sequence, 'name'), '.pdf', sep = ''))
	plot(starts, chunkGCs, type='b')
	dev.off()
	print(paste(attr(sequence, 'name'), ' done'))
}
