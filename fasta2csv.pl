#!/usr/bin/perl
use strict;
use warnings;

use Seqload::Fasta qw(fasta2csv); # oo access to fasta files

foreach my $file (@ARGV) {
	my $infh = Seqload::Fasta->open($file);
	while (my ($hdr, $seq) = $infh->next_seq()) {
		printf "%s,%s\n", $hdr, $seq;
	}
	$infh->close();
}
