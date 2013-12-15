#!/usr/bin/perl
use strict;
use warnings;

use Tie::File;
use File::Spec;

print "Good day, Sir.\n";
die "For proper operation, I'm going to need /two/ arguments from you, Sir.\n" unless scalar @ARGV == 2;
my ($string, $estfile) = @ARGV;

tie(my @file, 'Tie::File', $estfile) or die "I'm sorry, but I could not tie $estfile, Sir\n";

for (my $i = 0; $i < @file; ++$i) {
	if ($file[$i] =~ /$string/) {
		print "I found $string in line " , $i+1 , ", Sir.\n";
		last;
	}
}
