#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use Getopt::Long;

my $species_name = '';

my $opts = GetOptions(
	'species=s' => \$species_name
) or die;

my @interestinglines;
my $genome_size = 0;
my $file_name = '';

while (<>) {
	if (/^file name:\h*(.+)$/) {
		$file_name = $1;
	}
	elsif (/^total length:\h+(\d+) bp/) {
		$genome_size = $1;
	}
	elsif (/^Total interspersed repeats:\h*(\d+) bp/) {
		push @interestinglines, { file => $file_name, genome_size => $genome_size, type => 'Total interspersed repeats', value => $1 };
	}
	elsif (/^SINEs:\h+\d+\h+(\d+) bp\h+/) {
		push @interestinglines, { file => $file_name, genome_size => $genome_size, type => 'SINEs', value => $1 };
	}
	elsif (/^LINEs:\h+\d+\h+(\d+) bp\h+/) {
		push @interestinglines, { file => $file_name, genome_size => $genome_size, type => 'LINEs', value => $1 };
	}
	elsif (/^LTR elements:\h+\d+\h+(\d+) bp\h+/) {
		push @interestinglines, { file => $file_name, genome_size => $genome_size, type => 'LTR elements', value => $1 };
	}
	elsif (/^DNA elements:\h+\d+\h+(\d+) bp\h+/) {
		push @interestinglines, { file => $file_name, genome_size => $genome_size, type => 'DNA elements', value => $1 };
	}
	elsif (/^Unclassified:\h+\d+\h+(\d+) bp\h+/) {
		push @interestinglines, { file => $file_name, genome_size => $genome_size, type => 'Unclassified elements', value => $1 };
	}
	elsif (/^Small RNA:\h+\d+\h+(\d+) bp\h+/) {
		push @interestinglines, { file => $file_name, genome_size => $genome_size, type => 'Small RNA', value => $1 };
	}
	elsif (/^Satellites:\h+\d+\h+(\d+) bp\h+/) {
		push @interestinglines, { file => $file_name, genome_size => $genome_size, type => 'Satellites', value => $1 };
	}
	elsif (/^Simple repeats:\h+\d+\h+(\d+) bp\h+/) {
		push @interestinglines, { file => $file_name, genome_size => $genome_size, type => 'Simple repeats', value => $1 };
	}
	elsif (/^Low complexity:\h+\d+\h+(\d+) bp\h+/) {
		push @interestinglines, { file => $file_name, genome_size => $genome_size, type => 'Low complexity', value => $1 };
	}
}

foreach my $line (@interestinglines) {
	print join("\t", $species_name ? $species_name : $line->{file}, $line->{genome_size}, $line->{type}, $line->{value}), "\n";
}
