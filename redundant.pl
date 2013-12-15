#!/usr/bin/perl
use strict;
use warnings;

my $inf = shift(@ARGV) or die "Usage: $0 hamstrsearchXXX.out\n";

my %dupes;

# read log file, note duplicates
open(my $infh, '<', $inf) or die "Could not open $inf\: $!\n";
while (my $line = <$infh>) {
	my @fields = split('\|', $line);
	$fields[3] =~ s/-[0-9]*//g;
	# split by 'PP' and increment the headcount
	$fields[3] = [ split('PP', $fields[3]) ];
	$dupes{$_}++ foreach (@{$fields[3]});
}
close($infh);

# print headers if their count > 1
print "Redundant headers found:\n";
printf "%s, %d times\n", $_, $dupes{$_} foreach sort(grep(($dupes{$_} > 1), keys(%dupes)));
