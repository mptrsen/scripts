#!/usr/bin/env perl
use strict;
use warnings;
use autodie;

use File::Spec;
use IO::File;

my $inf = shift @ARGV or die "gimme a file\n";
my $outf = '';
my $outfh = undef;
my $nseqs = 0;

open my $infh, '<', $inf or die "Fatal: could not open '$inf' for reading: $!\n";

while (<$infh>) {
	chomp;
	if (/^# Assembly: ([A-Za-z0-9-]+) \[(e\d)\] \((\w+) (\w+)/) {
		print "$nseqs sequences in $outf\n" unless $nseqs == 0;
		undef $outfh;
		$nseqs = 0;
		$outf = File::Spec->catfile("$1_$2_$3_$4.fa");
		$outfh = IO::File->new($outf, 'a');
	}
	if (/^>/) {
		print $outfh "$_\n";
		++$nseqs;
	}
	if (/^[^#>]/) {
		print $outfh "$_\n";
	}
}
print "$nseqs sequences in $outf\n" unless $nseqs == 0;
