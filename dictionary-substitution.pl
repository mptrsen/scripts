#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use Getopt::Long;

my $dictf = '';

GetOptions( 'f=s' => \$dictf) or die "Error in command line arguments\n";

my $usage = "Replace words from a dictionary in a file\n";
$usage   .= "Usage: $0 DICTIONARY INPUTFILE";

-f $dictf or die "Fatal: Not a file: '$dictf'\n";

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

while (my $line = <>) {
	chomp $line;
	if ($line =~ m/\b($regex)\b/) {
		$line =~ s/\b($regex)\b/$dict{$1}/;
	}
	print $line, "\n";
}
