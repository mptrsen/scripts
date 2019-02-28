#!/usr/bin/awk
# simply add up all numbers and output the sum
{
	s += $1
}
END {
	print s
}
