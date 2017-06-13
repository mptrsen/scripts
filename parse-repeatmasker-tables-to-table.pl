#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use Getopt::Long;

my $species_name = '';
my $print_header = 0;

my $opts = GetOptions(
	'species=s' => \$species_name,
	'print-header|p' => \$print_header,
) or die;

my @interestinglines;
my $genome_size = 0;
my $file_name = '';

# define the elements I want to collect
my @interestingelements = (
	'Total interspersed repeats',
	'SINEs',
	'LINEs',
	'LTR elements',
	'DNA elements',
	'Unclassified',
	'Small RNA',
	'Satellites',
	'Simple repeats',
	'Low complexity',
);

# go through each input file, picking out file name and total length as well as
# total repeat coverage also collect the elements defined above by pushing an
# anonymous hash reference with the data I need to the stack
while (<>) {
	if (/^file name:\h*(.+)$/) {
		$file_name = $1;
	}
	elsif (/^total length:\h+(\d+) bp/) {
		$genome_size = $1;
	}
	elsif (/^(Total interspersed repeats):\h*(\d+) bp/) {
		push @interestinglines, { file => $file_name, genome_size => $genome_size, type => $1, value => $2 };
	}
	else {
		foreach my $elem (@interestingelements) {
			if (/^($elem):\h+\d+\h+(\d+) bp\h+/) {
				push @interestinglines, { file => $file_name, genome_size => $genome_size, type => $1, value => $2 };
			}
		}
	}
}

# done collecting, output
if ($print_header) {
	print join("\t", 'genome', 'genome size', 'element type', 'element coverage'), "\n";
}
foreach my $line (@interestinglines) {
	print join("\t", $species_name ? $species_name : $line->{file}, $line->{genome_size}, $line->{type}, $line->{value}), "\n";
}
