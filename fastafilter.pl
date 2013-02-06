#!/usr/bin/perl
use strict;
use warnings;

use File::Spec;
use Seqload::Fasta;
use IO::File;

die("Graarl\n") unless (scalar(@ARGV) == 1);
my $fh = Seqload::Fasta->open($ARGV[0]);
my $outfh = IO::File->new(File::Spec->catfile($ARGV[0] . '.reset'), 'w');
while (my ($hdr, $seq) = $fh->next_seq()) {
	if ($hdr =~ /PHUMA/) {
		my @fields = split(/\s+/, $hdr);
		my @subfields = split(/\|/, $fields[3]);
		$fields[3] = $subfields[1];
		$hdr = '';
		$hdr .= "$_ "  foreach @fields;
		printf $outfh ">%s\n%s\n", $hdr, $seq or die "Hurrl\n";
	}
	else {
		printf $outfh ">%s\n%s\n", $hdr, $seq or die "Hurrl\n";
	}
}
$outfh->close();
$fh->close();
print "OK";
