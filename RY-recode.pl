#!/usr/bin/perl
use strict;
use warnings;

die "give me a file to munch on" unless @ARGV;

my $infile = shift @ARGV;
my $outfile = "$infile.out";
print 'reading from ' . $infile . "\n";
print 'writing to ' . $outfile . "\n";

open(my $infh, '<', $infile) or die "Fatal: Could not open infile: $!\n";
open(my $outfh, '>', $outfile) or die "Fatal: Could not open outfile: $!\n";
while (<$infh>) {
	if (/^>/) {
		print $outfh $_;
		next;
	}
	tr/AGCTagct/RRYYrryy/;
	s/[^RY\n-]/N/g;
	print $outfh $_;
}
close $infh;
close $outfh;
print "Done\n";
