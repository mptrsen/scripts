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
	Q0 = quartile(c, 0)
	Q1 = quartile(c, 1)
	Q2 = quartile(c, 2)
	Q3 = quartile(c, 3)
	Q4 = quartile(c, 4)

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
	printf("%-12s %-14s %-12s %-12s %-12s %-12s %-12s %-12s %-12s %-12s\n", "n", "sum", "min", "lower", "mean", "median", "upper", "max", "stdev", "N50")
	printf("%-12s %-14s %-12s %-12s %-12s %-12s %-12s %-12s %-12s %-12s\n", r("-", 12), r("-", 14), r("-", 12), r("-", 12), r("-", 12), r("-", 12), r("-", 12), r("-", 12), r("-", 12), r("-", 12))
	printf("%-12d %-14f %-12f %-12f %-12f %-12f %-12f %-12f %-12f %-12f\n",  n,   sum,   Q0,    Q1,      mean,   Q2,       Q3,      Q4,    stdev,   N50)
	print "---" * 15
}

function r(s, n) {
	res = ""
	for (i = 0; i < n; i++) {
		res = res s
	}
	return res
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
	return quartile(nums, 2)
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

# determine distribution quartiles (0 = min, 2 = median, 4 = max)
function quartile(nums, p) {
	q = p/4
	l = length(nums)
	t = (l-1)*q+1 # our array is one-based
	v = nums[ int(t) ]
	if (t > int(t)) { return v + q * (nums[ int(t) + 1 ] - v) }
	else            { return v }
}
