#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;

my $infile = shift @ARGV;
my $outfile = $infile.'.out';
my %duplet;
my $max_n = 14;
my $max_n_perc = 0.1;
open(my $infh, '<', $infile)
	or die "Fatal: Could not open $infile: $!\n";

open(my $outfh, '>', $outfile)
	or die "Fatal: Could not open $outfile for writing: $!\n";

while (<$infh>) {
	chomp; 
	if (/^>/) {
		if (defined $duplet{'seq'}) {	# for all but the first one
			# if the current seq falls into the exclusion criteria
			my $num_n = &N_num(\%duplet);
			if (($num_n / length $duplet{'seq'} >= $max_n_perc) or &N_14(\%duplet)) {
				print $outfh $duplet{'hdr'} . ':' . $num_n . 'N' . "\n", $duplet{'seq'}, "\n";
			}
			print $duplet{'hdr'}, " has more than ", $max_n_perc * 100, "% N\n" if ($num_n / length $duplet{'seq'} >= $max_n_perc);
			print $duplet{'hdr'}, " has more than $max_n Ns in a row\n" if (&N_14(\%duplet));
		}
		$duplet{'hdr'} = $_;
		$duplet{'seq'} = '';
	}
	else {
		$duplet{'seq'} .= $_;
	}
}
my $num_n = &N_num(\%duplet);
if (($num_n / length $duplet{'seq'} >= $max_n_perc) or &N_14(\%duplet)) {
	print $outfh $duplet{'hdr'}, "\n", $duplet{'seq'}, "\n";
}
print $duplet{'hdr'}, " has more than ", $max_n_perc * 100, "% N\n" if (($num_n / length $duplet{'seq'} >= $max_n_perc) or &N_14(\%duplet));
print $duplet{'hdr'}, " has more than $max_n Ns in a row\n" if (&N_14(\%duplet));
close $outfh;
print "Filtered sequences saved to $outfile.\n";

#--------------------------------------------------
# functions 
#-------------------------------------------------- 

sub N_num {
	my $duplet = shift @_;	# is a hash ref
	my $seqlen = length $$duplet{'seq'};
	my $num_n = 0;
	++$num_n while ($$duplet{'seq'} =~ /n/gi);
	my $perc_n = $num_n ? $num_n / $seqlen : 0;	# calculate N percentage
	return $num_n;
}

sub N_14 {
	my $duplet = shift @_;	# is a hash ref
	return 1 if ($$duplet{'seq'} =~ /n{$max_n,}/i);	# if there are more than 14 N
	return 0;	# otherwise
}
