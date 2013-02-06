#!/usr/bin/perl
use strict;
use warnings;

use Seqload::Fasta;
use Getopt::Long;
use File::Spec;
use Cwd;

my $pwd = getcwd();
my $maxseqs = 99999999999999999;
my $nseqs = 0;

GetOptions(
	'maxseqs=s'  => \$maxseqs,
);

open(my $listfh, '<', $ARGV[0]) or die "Could not open list file: $!\n";
my @taxlist = <$listfh>;
close $listfh;
chomp @taxlist;

my $fh = Seqload::Fasta->open($ARGV[1]);

while (my ($hdr, $seq) = $fh->next_seq()) {
	if (grep {$hdr =~ /^$_/} @taxlist) {
		$nseqs++;
		printf ">%s\n%s\n", $hdr, $seq;
	}
	last if $nseqs >= $maxseqs;
}

undef $fh;
