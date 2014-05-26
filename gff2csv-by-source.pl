#!/usr/bin/perl
use strict;
use warnings;
use autodie;

my $fh;
my $fn;
my @F;
my $s = '';

while (<>) {
	next unless /AED=/;
	@F = split;
	if ($s ne $F[1]) {
		print "filename: $F[1]\n";
		$s = $F[1];
		$fn = '/tmp/Oabi-maker/' . $s . '.csv';
	}
	$F[8] =~ /AED=(\d.\d+);_eAED=(\d.\d+)/;
	open $fh, '>>', $fn;
	printf $fh "%s,%s,%d,%d,%.2f,%.2f\n", $F[0], $F[1], $F[3], $F[4], $1, $2;
	close $fh;
}
