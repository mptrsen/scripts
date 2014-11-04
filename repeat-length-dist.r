#!/usr/bin/R

# to be called like this:
#
#   R -f scriptfile.r INPUTFILE INPUTFILE INPUTFILE ...
#
sh = function(n) {
	return(substr(basename(n), 1, 4))
}

# get list of input files
args = commandArgs()
files = c(args[4:length(args)])

# list of names from filenames, using the first 4 chars
names = lapply(files, sh)


# fill a list with names => list of files
prefix = names[[1]]
plots = list()
for (i in 1:length(names)) {
	if (names[[i]] != prefix) {
		prefix = names[[i]]
	}
	plots[[prefix]] = c(plots[[prefix]], files[[i]])
}


for (name in names(plots)) {
	fn    = paste('/tmp/', name, '.pdf', sep='')
	label = paste(name, 'repeat distribution')

	rows = 2
	cols = 1

	# 1 or 2 columns?
	if (length(plots[[name]]) > 1) {
		cols = as.integer(length(plots[[name]]) / rows)
	}

	# is there a remainder? if so, we need one more row
	if (length(plots[[name]]) %% rows != 0) {
		rows = rows+1
	} 

	# open pdf file
	pdf(fn, width=11.6, height=4.1*rows)
	# set # of rows and columns as well as inner margins
	par(mfrow=c(rows,cols), mar=c(5.1,4.1,8,2.1))

	for (file in plots[[name]]) {
		d = read.csv(file, header=F)
		barplot(d$V4, names.arg=d$V1, main=label, xlab='unit length', ylab='bp/Mbp')
		mtext(basename(file), line=2)
		
	}
	dev.off()
}


