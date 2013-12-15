#!/usr/bin/perl
use strict;
use warnings;

use Seqload::Fasta;

my @infiles = @ARGV;
die "No files in argument list\n" if scalar @infiles == 0;

foreach my $infile (@infiles) {
	my $infh = Seqload::Fasta->open($infile);
	while (my ($hdr, $seq) = $infh->next_seq()) {
		printf("%s,%s\n", $hdr, $seq);
	}
}
