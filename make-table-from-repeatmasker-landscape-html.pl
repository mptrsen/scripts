#!/usr/bin/perl
use strict;
use warnings;
use autodie;

my $usage = "USAGE: $0 repeat-landscape.html\n";

my $inf = shift @ARGV or die $usage;

die "Not a HTML file?\n" unless $inf =~ /\.html$/;

(my $outf = $inf) =~ s/\.html$/-data.txt/;
(my $pief = $inf) =~ s/\.html$/-pie-data.txt/;

my @columns;
my @interestinglines;
my @pielines;

open my $fh, '<', $inf;
while (<$fh>) {
	if (/^\s+data\.addColumn/) {
		/\('\w+', '(.+)'\)/;
		push @columns, $1;
	}
	elsif (/^\s+\['\d+'/) {
		push @interestinglines, $_;
	}
	elsif (/^\s+\['\w+/) {
		push @pielines, $_;
	}
}
close $fh;

# make the matrix for the landscape data
my $matrix = [ ];

open my $outfh, '>', $outf;

print $outfh join("\t", @columns), "\n";
foreach my $line ( @interestinglines ) {
	$line =~ s/^\s+\['//;
	$line =~ s/\],\s*$//;
	$line =~ s/'//g;
	print $outfh join("\t", split /,\s*/, $line), "\n";
}

close $outfh;

# make the table for the pie data
open my $piefh, '>', $pief;

foreach my $line ( @pielines ) {
	$line =~ s/^\s+\['//;
	$line =~ s/\],\s*$//;
	$line =~ s/'//g;
	print $piefh join("\t", split /,\s*/, $line ), "\n";
}

close $piefh;

exit;
