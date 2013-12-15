#!/usr/bin/perl
use strict;
use warnings;

print "Good day, Sir.\n";
die "For proper operation, I'm going to need /two/ arguments from you, Sir.\n" unless scalar @ARGV == 2;
my ($string, $estfile) = @ARGV;

for (my $i = 0; $i < 10000; ++$i) {
	`grep -m 1 -c $string $estfile`;
}
