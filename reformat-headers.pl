#!/usr/bin/perl
use strict;
use warnings;

use Seqload::Fasta;
use File::Spec;
use Cwd;

my $pwd = getcwd();
my $maxseqs = 40;
my $nseqs;

open(my $listfh, '<', $ARGV[0]) or die "Could not open list file: $!\n";
my @taxlist = <$listfh>;
close $listfh;
chomp @taxlist;

my $fh = Seqload::Fasta->open($ARGV[1]);

while (my ($hdr, $seq) = $fh->next_seq()) {
	foreach my $tax (@taxlist) {
		if ($hdr =~ $tax) {
			$nseqs++;
			my @fields = split(/\s+/, $hdr);
			$fields[0] =~ s/:.*//;	# this removes the colon and everything after it from the taxon field
			$fields[3] =~ s/.*\|//;	# this removes all pipe-separated fields but the last one (if any) from the sequence identifier field
			open (my $outfh, '>>', File::Spec->catfile($pwd, 'genes_aa', $fields[2] . '.fa')) or die "Wah! $!\n";
			printf $outfh (">%s|%s\n%s\n", $fields[0], $fields[3], $seq) or die "$!\n";
			close $outfh;
		}
	}
	last if $nseqs >= $maxseqs;
}
$fh->close();
print "OK\n";
