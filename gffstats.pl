#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use Data::Dumper;

my $usage = "$0 GFFFILE\n";

my $inf = shift @ARGV or print $usage and exit;

open my $fh, '<', $inf;

my $d = { };

while (<$fh>) {
	next if /^#/;
	my @f = split /\s+/;
	$d->{$f[1]}->{$f[2]}++;

	if (/AED=(\d\.\d+);_eAED=(\d\.\d+)/) {
		if ($1 > 0.5) {
			$d->{$f[1]}->{'aed_above_threshold'}++;
		}
		else {
			$d->{$f[1]}->{'aed_below_threshold'}++;
		}
	}
}

my $sum_types = {};
my $sum_sources = {};

print "Unique combinations:\n";

foreach my $pk (sort keys %$d) {
	my $s = 0;
	foreach my $sk (keys %{$d->{$pk}}) {
		$sum_sources->{$pk} += $d->{$pk}->{$sk};
		$sum_types->{$sk} += $d->{$pk}->{$sk};
		printf "\t%s, %s: %d\n", $pk, $sk, $d->{$pk}->{$sk};
	}
}

print "Feature sources:\n";
foreach my $k (sort keys %$sum_sources) {
	printf "\t%s: %d\n", $k, $sum_sources->{$k};
}

print "Feature types:\n";
my $aed_above = $sum_types->{'aed_above_threshold'};
my $aed_below = $sum_types->{'aed_below_threshold'};

foreach my $k (sort keys %$sum_types) {
	if ($k =~ /^mRNA/) {
		printf "\t%s: %d\n\t\t%s: %d\n\t\t%s: %d\n", $k, $sum_types->{$k}, 'AED below threshold', $aed_above, 'AED below threshold', $aed_below;
	}
	else {
		printf "\t%s: %d\n", $k, $sum_types->{$k};
	}
}

