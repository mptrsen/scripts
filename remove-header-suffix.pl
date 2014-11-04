#!/usr/bin/perl
use strict;
use warnings;
use autodie;

use Seqload::Fasta;

my $f = shift @ARGV or die "Usage: $0 FASTAFILE\n";

my $dictf = $f . '.dict';

my $fh = Seqload::Fasta->open($f);

open my $dictfh, '>', $dictf;

while (my ($h, $s) = $fh->next_seq()) {
	my $nh = $h;
	$nh =~ s/-[RPT][A-H]$//;
	$nh =~ s/\|/_/g;
	printf $dictfh "%s -> %s\n", $h, $nh;
	printf ">%s\n%s\n", $nh, $s;
}
