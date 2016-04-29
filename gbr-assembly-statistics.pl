#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use Tie::File;

my $inf = shift @ARGV;

tie my @f, 'Tie::File', $inf;

my $L_t;
my $L_i_0;
my $L_i_1000;
my $L_i_5000;
my $L_i_10000;
my $L_i_25000;
my $L_i_50000;
my $sum_L_i;
my $n50;
my $busco_complete;
my $busco_fragmented;
my $mapped_reads;
my $mapped_pairs;

for (my $i = 0; $i < scalar @f; $i++) { 
	if ($i < 2) {
		print $f[$i], "\n";
		next;
	}
	my @fields = split /\t/, $f[$i];
}
