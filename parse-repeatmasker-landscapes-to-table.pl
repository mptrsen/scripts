#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use lib '/home/mpetersen/lib';
use Text::Table;

my @interestinglines;

while (<>) {
	if (/^\s+data\.addColumn/) {
		push @interestinglines, $_;
	}
	elsif (/^\s+var pieData/) {
		last;
	}
	elsif (/^\s+\[/) {
		push @interestinglines, $_;
	}
}

my $matrix = [ ];
my @columns;

foreach my $line ( grep { /addColumn/ } @interestinglines ) {
	$line =~ /\('\w+', '(.+)'\)/;
	push @columns, $1;
}

my $table = Text::Table->new( @columns );


foreach my $line ( grep { /\[/ } @interestinglines ) {
	$line =~ s/^\s+\['//;
	$line =~ s/\],\s*$//;
	$line =~ s/'//g;
	my @row = split /, /, $line;
	$table->add( @row );
}

print $table and exit;
