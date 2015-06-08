#!/usr/bin/perl
# replaces Fasta headers with IDs, create a dictionary 
# input: Fasta file
# output: 2 files:
#	  - file.dict: dictionary, records are in the format "header -> ID"
#	  - file.new: Fasta file with replaced headers
use strict;
use warnings;
use autodie;

my $fn = shift or die;

my $id = 0;

open my $dictfh, '>', $fn . '.dict';
open my $newfh, '>', $fn . '.new';

open my $fh, '<', $fn;

while (<$fh>) {
	if (s/^>//) {
		chomp;
		printf $dictfh "%s -> %05d\n", $_, $id;
		printf $newfh ">%05d\n", $id;
		$id++;
	}
	else { print $newfh $_ }
}

close $fh;
close $dictfh;
close $newfh;
