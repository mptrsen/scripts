#!/usr/bin/perl
use strict;
use warnings;

print "Good day, Sir.\n";
die "For proper operation, I'm going to need /two/ arguments from you, Sir.\n" unless scalar @ARGV == 2;
my ($string, $estfile) = @ARGV;

for (my $i = 0; $i < 1000; ++$i) {
	open(my $fh, '<', $estfile) or die "I'm sorry, but I could not open the file, Sir.\n";
	my @lines = <$fh>;
	close($fh);
	foreach(@lines) {
		if ($_ =~ /$string/) {
			last;
		}
	}
	@lines = ();
}
