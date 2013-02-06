#!/usr/bin/perl

# Remove all gaps from a fasta file.
# Requires Seqload::Fasta.

use strict;
use warnings;
use Seqload::Fasta;

die "Usage: $0 FASTAFILE\n" unless scalar @ARGV == 1;

my $inf = Seqload::Fasta->open($ARGV[0]);
while (my ($h, $s) = $inf->next_seq()) {
	$s =~ s/-//g;	# remove all gap characters
	printf(">%s\n%s\n", $h, $s);
}
