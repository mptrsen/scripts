#!/usr/bin/perl
use strict;

my $file = $ARGV[0];
my %data;
my $data_by_values;

open(my $fh, $file) or die "$!\n";
while (<$fh>) {
	next if /^>/;	# skip fasta headers
	chomp;
	++$data{length($_)};	# auto-initialized!
}
close($fh) or die "$!\n";

foreach (sort( {$a <=> $b} keys %data)) {
	print $_, "\t", $data{$_}, "\n";
}
