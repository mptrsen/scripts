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
	N90 = n90(c)

	# output
	len_n = length(n)
	len_sum   = length(sprintf("%s", sum))
	len_Q0    = length(sprintf("%s", Q0))
	len_Q1    = length(sprintf("%s", Q1))
	len_Q2    = length(sprintf("%s", Q2))
	len_Q3    = length(sprintf("%s", Q3))
	len_Q4    = length(sprintf("%s", Q4))
	len_mean  = length(sprintf("%s", mean))
	len_stdev = length(sprintf("%s", stdev))
	len_N50   = length(sprintf("%s", N50))
	len_N90   = length(sprintf("%s", N90))
	# make the length fit nicely
	len_sum   = len_sum > 3   ? len_sum   : 3 # sum
	len_Q0    = len_Q0 > 3    ? len_Q0    : 3 # min
	len_Q1    = len_Q1 > 4    ? len_Q1    : 4 # Q1
	len_Q2    = len_Q2 > 4    ? len_Q2    : 4 # median
	len_Q3    = len_Q3 > 4    ? len_Q3    : 4 # Q3
	len_Q4    = len_Q4 > 3    ? len_Q4    : 3 # max
	len_mean  = len_mean > 4  ? len_mean  : 4 # mean
	len_stdev = len_stdev > 5 ? len_stdev : 5 # stdev
	len_N50   = len_N50 > 3   ? len_N50   : 3 # N50
	len_N90   = len_N90 > 3   ? len_N90   : 3 # N90
	format = "%-" len_n "s %-" len_sum "s %-" len_Q0 "s %-" len_Q1 "s %-" len_mean "s %-" len_Q2 "s %-" len_Q3 "s %-" len_Q4 "s %-" len_stdev "s %-" len_N50 "s %-" len_N90 "s\n"
	printf(format, "n",           "sum",           "min",           "lowr",       "mean",           "medn",       "uppr",        "max",          "stdev",           "N50",           "N90")
	printf(format, r("-", len_n), r("-", len_sum), r("-", len_Q0), r("-", len_Q1), r("-", len_mean), r("-", len_Q2), r("-", len_Q3), r("-", len_Q4), r("-", len_stdev), r("-", len_N50), r("-", len_N90))
	printf(format, n,             sum,             Q0,              Q1,            mean,             Q2,             Q3,             Q4,             stdev,             N50,             N90)
}

function r(s, n) {
	res = ""
	for (i = 0; i < n; i++) {
		res = res s
	}
	return res
}

function n50(nums) {
	return nX(50, nums)
}

function n90(nums) {
	return nX(90, nums)
}

function nX(X, nums) {
	fraction = X / 100
	total = 0
	for (i = 1; i < length(nums); i++) {
		total += nums[i]
	}
	subtotal = 0
	for (i = 1; i < length(nums); i++) {
		if (nums[i] + subtotal > total * fraction) {
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
