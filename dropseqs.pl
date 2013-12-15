#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;

# declare vars
my $infile = $ARGV[-1];
my $tracefile;
my %duplet;
my $maxlength = 200;	# default length 
my $help;
my $printseqs;

# handle options
&GetOptions (
	'l=s'	=> \$maxlength,
	't=s' => \$tracefile,
	's'		=> \$printseqs,
	'h'		=> \$help,
);

if (defined $help) { &usage }

die "Fatal: maxlength must be integer\n" 
	unless ($maxlength =~ /^\d+$/);

# prepare file handles
open (my $infh, $infile) 
	or die "Fatal: Could not open input file $infile: $!\n";

if (defined $tracefile) {
	open (TRACE, '>', $tracefile) 
		or die "Fatal: Could not open output file $tracefile: $!\n";
}

# collect sequences longer than $maxlength
while (<$infh>) {
	chomp;
	if (/^>/) {
		# print them to STDOUT
		if (defined $duplet{'seq'} and length($duplet{'seq'}) >= $maxlength) {
			print $duplet{'hdr'}, "\n";
			print $duplet{'seq'}, "\n";
		}
		# save shorter ones in tracefile, if defined
		elsif (defined $tracefile 
						and defined $duplet{'seq'}
						and length($duplet{'seq'}) < $maxlength) {
			print TRACE $duplet{'hdr'}, "\n";
			print TRACE $duplet{'seq'}, "\n" if defined $printseqs;
		}
		$duplet{'hdr'} = $_;
		$duplet{'seq'} = '';
	}
	else {
		$duplet{'seq'} .= $_;
	}
}

# close files
close $infh
	or die "Warning: Could not close input file $infile: $!\n";

if (defined $tracefile) {
	close TRACE 
		or die "Warning: Could not close output file $tracefile: $!\n";
}

# blegh
sub usage {
	print <<EOF;
Usage: $0 [-s] [-l maxlength] [-t tracefile] <fastafile>
Prints all sequences with lengths > maxlength to STDOUT. A tracefile may be specified via the -t option; in which case the omitted headers (option -s: along with their sequences) are collected there.
EOF
exit;
}
