#!/usr/bin/perl
use strict;
use warnings;

die "Usage: $0 FASTAFILE\n" unless scalar @ARGV == 1;

my $infile = shift @ARGV;

# anonymous hash with all the data
my $data = {};
my $spec = '';
my $perc;
my $total_sites;
my $total_isites;
my $total_perc;

# open file and read its content
open(my $fh, '<', $infile) or die "Fatal: Could not open infile: $!\n";
while (<$fh>) {
	chomp;
	# headers
	if (/^>/) {
		($spec = $_) =~ s/>//;
		$data->{$spec}->{'seq'} = '';
		next;
	}
	
	# accumulate sequences and their length
	$data->{$spec}->{'seq'} .= $_;
	$data->{$spec}->{'len'} += length $_;

	# count number of informative sites 
	while ($_ =~ /[^N-]/g) { ++$data->{$spec}->{'inf'} }
}
close $fh;

# add and output
printf "%32s%10s%10s% 10s% 10s\n", 'Species', 'Sites', 'iSites', '%iSites', '%missing';
print '-' x 72, "\n";
foreach (sort keys %$data) {
	$total_sites += $data->{$_}->{'len'};
	$total_isites += $data->{$_}->{'inf'};
	$perc = ($data->{$_}->{'inf'} / $data->{$_}->{'len'}) * 100;
	printf "%32s%10d%10d% 9.2f% 9.2f\n", $_ , $data->{$_}->{'len'} , $data->{$_}->{'inf'} , $perc, 100 - $perc;
}

# total
$total_perc = ($total_isites / $total_sites) * 100;
print '-' x 72, "\n";
printf "%32s%10d%10d\n", 'Total', $total_sites, $total_isites;
printf "%32s%10s%10s% 9.2f% 9.2f\n", 'Average', '', '', $total_perc, 100 - $total_perc;
