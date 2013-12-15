#!/usr/bin/perl
use strict;
use warnings;
use IO::File;

print "Good day, Sir.\n";
die "For proper operation, I'm going to need /two/ arguments from you, Sir.\n" unless scalar @ARGV == 2;
my ($string, $estfile) = @ARGV;

for (my $i = 0; $i < 1000; ++$i) {
	my $fh = IO::File->new();
	$fh->open($estfile) or die "I'm sorry, but I could not open the file, Sir.\n";
	my @lines = <$fh>;
	$fh = undef;
	foreach(@lines) {
		if ($_ =~ /$string/) {
			last;
		}
	}
	@lines = ();
}
