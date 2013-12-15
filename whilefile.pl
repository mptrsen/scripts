#!/usr/bin/perl
use strict;
use warnings;

die "For proper operation, I'm going to need /two/ arguments from you, Sir.\n" unless scalar @ARGV == 2;
my ($string, $estfile) = @ARGV;

for (my $i = 0; $i < 10000; ++$i) {
	open(my $fh, '<', $estfile) or die "I'm sorry, but I could not open the file, Sir.\n";
	while (<$fh>) {
		if ($_ =~ /$string/) {
			last;
		}
	}
	close($fh);
}
