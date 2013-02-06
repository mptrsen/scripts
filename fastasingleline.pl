#!/usr/bin/perl

# Prints FASTA files with sequences in a single line each

use strict;
use warnings;
use Seqload::Fasta;	# oo access to fasta files

die "Usage: $0 FASTAFILE\n" unless (scalar @ARGV);

foreach (@ARGV) {
	my $fh = Seqload::Fasta->open($_);
	while (my ($h, $s) = $fh->next_seq()) {
		printf(">%s\n%s\n", $h, $s);
	}
	$fh->close();
}
