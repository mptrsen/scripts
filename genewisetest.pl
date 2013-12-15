#!/usr/bin/perl
use strict;
use warnings;

my ($dna, $prot) = @ARGV;
my $gwresult = [`genewise -trans -cdna -pep -sum $dna $prot`];
die "genewise failed with error code: $?\n" if ($? > 0);
