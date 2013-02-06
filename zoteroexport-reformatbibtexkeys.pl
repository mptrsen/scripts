#!/usr/bin/perl
use strict;
use warnings;
use autodie;

my $inf = shift @ARGV;

open my $fh, '<', $inf;

my %seen = ( );

while (<$fh>) {
	unless (/^@/) { print and next }
	s/(\@\w+)\{([^_]+)_.+_([0-9]+)/$1\{\L$2\E$3/;
	defined $seen{"$2$3"} and s/,$/-1,/;
	print;
	$seen{"$2$3"}++;
}
