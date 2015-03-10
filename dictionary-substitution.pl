#!/usr/bin/perl
use strict;
use warnings;
use autodie;

my $usage = "Replace words from a dictionary in a file\n";
$usage   .= "Usage: $0 DICTIONARY INPUTFILE";

my $dictf  = shift @ARGV or die $usage;
my $dataf  = shift @ARGV or die $usage;

my %dict = ( );

open my $fh, '<', $dictf;

while (<$fh>) {
	chomp;
	my ($k, $v) = split /\s+/;
	$dict{$k} = $v;
}

close $fh;

my $regex = join("|", map { quotemeta } keys %dict);
$regex = qr/$regex/;

open $fh, '<', $dataf;

while (my $line = <$fh>) {
	chomp $line;
	if ($line =~ m/\b($regex)\b/) {
		$line =~ s/\b($regex)\b/$dict{$1}/;
	}
	print $line, "\n";
}

close $fh;
