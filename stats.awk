#!/usr/bin/awk

# calculate the median
# requires that the input list is sorted!

{
	# save and sum everything
	c[NR] = $1
	sum  += $1
}

END {
	# determine median
	if (NR % 2) {
		# odd number of samples,
		# median = middle value
		median = c[ (NR + 1) / 2 ]
	}
	else {
		# even number of samples,
		# median = average of the two middle values
		median = ( c[ NR / 2 ] + c[ NR / 2 + 1 ] ) / 2
	}
	# calculate mean
	mean = sum / NR
	# calculate standard deviation
	for (i in c) {
		sqdiff += ( i - mean ) ** 2
	}
	stdev = sqrt(sqdiff/NR)

	print "mean:", mean, "median:", median, "stdev:", stdev
}
