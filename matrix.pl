#!/usr/bin/perl
use strict;
use warnings;

# matrix
my $m = [];

# construction part
foreach my $i (0..9) {
	$m->[$i] = [ ];
	foreach my $j (0..9) {

		# data part
		$m->[$i]->[$j] = &area($i + $j);
	}
}

# output
# header
printf " % 6d ", $_ foreach (0..9);
print "\n";
print ' +', '-' x 79, "\n";
# rows
foreach my $y (0..9) {
	print $y . '|' ;
	# columns
	foreach my $x (0..9) {
		printf "% 7.1f ", $m->[$y]->[$x];
	}
	print "\n";
}

sub area {
	my $PI = 3.14159;
	return $PI * (shift(@_) ** 2);
}
