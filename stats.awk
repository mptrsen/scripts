#!/usr/bin/gawk -f

# calculate some statistics (min, max, mean, median, stdev, etc)
# requires that the input list is sorted!

{
	# save and sum everything
	c[NR] = $1
	sum  += $1
}

END {
	# get median
	Q2 = median(c)

	# get upper and lower quartiles
	Q1 = quartile(c, 1)
	Q3 = quartile(c, 2)

	# calculate mean
	mean = sum / NR

	# calculate standard deviation, determine min and max
	min = c[1]
	max = c[1]
	n = 0
	for (i in c) {
		n++
		sqdiff += ( c[i] - mean ) ** 2
		if (c[i] > max) { max = c[i] }
		if (c[i] < min) { min = c[i] }
	}
	stdev = sqrt(sqdiff/NR)
	N50 = n50(c)

	# output
	print "n:", n, "sum:", sum, "min:", min, "max:", max, "mean:", mean, "lower:", Q1, "median:", Q2, "upper:", Q2, "stdev:", stdev, "N50:", N50
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
		return ( nums[ n/2 ] + c[ n/2 + 1 ] ) / 2
	}
}

# slice an array
function slice(array, start, end) {
	j = 1
	for (i = start; i < end; i++) {
		tmparray[j] = array[i]
		j++
	}
}

# determine quartiles
function quartile(array, quart) {
	halfindex = length(array)/2
	if (quart == 1) {
		slice(array, 1, halfindex)
		return median(tmparray)
	}
}
