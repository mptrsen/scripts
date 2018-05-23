#!/usr/bin/perl
use strict;
use warnings;
use autodie;

while (my $acc = <>) {
	chomp $acc;
	my $urlfmt = "ftp://ftp.ncbi.nlm.nih.gov/genomes/all/%s/%03d/%03d/%03d/%s/%s_genomic.fna.gz";
	my $url_dir1 = substr($acc, 0, 3);
	my $url_dir2 = substr($acc, 4, 3); # skip the underscore
	my $url_dir3 = substr($acc, 7, 3);
	my $url_dir4 = substr($acc, 10, 3);
	printf $urlfmt . "\n",
		$url_dir1,
		$url_dir2,
		$url_dir3,
		$url_dir4,
		$acc,
		$acc,
	;
}
