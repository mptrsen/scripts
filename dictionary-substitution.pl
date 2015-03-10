#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use Getopt::Long;

my $usage = "Replace words from a tab-separated dictionary in a file or standard input\n";
$usage   .= "Usage: $0 -f DICTIONARY [INPUTFILE]";

my $dictf;

GetOptions( 'f=s' => \$dictf) or die "Error in command line arguments\n$usage\n";

die "$usage\n" unless defined $dictf;

die "Fatal: Not a file: '$dictf'\n" unless -f $dictf;

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
