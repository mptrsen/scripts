#!/usr/bin/perl
use strict;
use warnings;

use Seqload::Fasta;

my $inf = shift @ARGV;

my $infh = Seqload::Fasta->open($inf);
while (my ($hdr, $seq) = $infh->next_seq()) {
	my @fields = split(/\|/, $hdr);
	s/\s+$// foreach @fields;
	printf(">%s\n%s\n", $fields[0], $seq);
}
