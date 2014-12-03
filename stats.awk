#!/usr/bin/awk

# calculate some statistics (min, max, mean, median, stdev, etc)
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
		median = ( c[ NR/2 ] + c[ NR/2 + 1 ] ) / 2
	}
	# calculate mean
	mean = sum / NR
	# calculate standard deviation, determine min and max
	min = c[1]
	max = c[1]
	for (i in c) {
		sqdiff += ( i - mean ) ** 2
		if (c[i] > max) { max = c[i] }
		if (c[i] < min) { min = c[i] }
	}
	stdev = sqrt(sqdiff/NR)

	print "sum:", sum, "min:", min, "max:", max, "mean:", mean, "median:", median, "stdev:", stdev
}
