#!/usr/bin/perl
use strict;
use warnings;
use autodie;
while (<>) {
	# split by tabs
	my @fields = split /\t/;
	# separate species name
	my ($gen, $spec) = split ' ', $fields[4];
	# remove -PA suffix
	$fields[2] =~ s/-[PR][A-Z]$//;
	# print 6 tab-separated fields for Orthograph
	printf "%s\t" x 6 . "\n",
		$fields[0],                                    # cog id
		'2',
		$fields[2],                                    # protein id
		'4',
		'5',
		$spec ? uc(substr($gen, 0, 1) . substr($spec, 0, 4)) : $fields[4],  # taxon shorthand
	;
}
