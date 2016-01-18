#!/usr/bin/gawk -f

# calculate some statistics (min, max, mean, median, stdev, etc)
# requires that the input list is sorted!

{
	# save and sum everything
	c[NR] = $1
	sum  += $1
}

END {

	# get upper and lower quartiles and median (2nd quartile)
	Q1 = quartile(c, 1)
	Q2 = median(c)
	Q3 = quartile(c, 3)


	# determine n and calculate mean
	n = length(c)
	mean = sum / n

	# calculate standard deviation, determine min and max
	min = c[1]
	max = c[length(c)]
	for (i in c) {
		sqdiff += ( c[i] - mean ) ** 2
	}
	stdev = sqrt(sqdiff/NR)
	N50 = n50(c)

	# output
	print "n:", n, "sum:", sum, "min:", min, "max:", max, "mean:", mean, "lower:", Q1, "median:", Q2, "upper:", Q3, "stdev:", stdev, "N50:", N50
}

function n50(nums) {
	total = 0
	for (i = 1; i < length(nums); i++) {
		total += nums[i]
	}
	subtotal = 0
	for (i = 1; i < length(nums); i++) {
		if (nums[i] + subtotal > total / 2) {
			return nums[i]
		}
		else {
			subtotal += nums[i]
		}
	}
}

# determine median
function median(nums) {
	n = length(nums)
	if (n % 2) {
		# odd number of samples,
		# median = middle value
		return nums[ (n + 1) / 2 ]
	}
	else {
		# even number of samples,
		# median = average of the two middle values
		return ( nums[ n/2 ] + nums[ n/2 + 1 ] ) / 2
	}
}

function quartile(nums, quart) {
	n = length(nums)
	if (n * quart / 4 % 2) {
		return ( nums[ ceil( n * quart / 4 ) ] )
	}
	else {
		return ( ( nums[ ceil( n * quart / 4 ) ] + nums[ floor( n * quart / 4  ) ] ) / 2)
	}
}

function ceil(x) {
	if (x < 0) {
		return ( x == int(x) ? x : int(x) )
	}
	return ( x == int(x) ? x : int(x)+1 )
}

function floor(x) {
	if (x < 0) {
		return ( x == int(x) ? int(x) -1 : x )
	}
	return ( int(x) )
}
