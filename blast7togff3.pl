#!/usr/bin/perl

# convert a BLAST output file (in BLAST output format 7) to a GFF3 file
#

use strict;
use warnings;
use autodie;
use File::Basename;

# sequence source feature start end . strand . descr
my $outfmt = "%s\t%s\t%s\t%d\t%d\t%.1f\t%s\t%s\t%s\n";
my $db = '';
my %scaffolds = ( );

print "##gff-version 3\n";

while (<>) {
	if (/Database:\s(\S+)$/) {
		$db = basename $1;
	}
	next if /^#/;
	my @f = split /\s+/;
	my $strand = $f[6] < $f[7] ? '+' : '-';
	++$scaffolds{$f[0]};
	my $id = sprintf "ID=tblastx-%s-%s:hsp:%06d",
		$f[0],
		$db,
		$scaffolds{$f[0]},
	;
	printf $outfmt,
		$f[0],
		'tblastx',
		'hit', 
		$strand eq '+' ? $f[6] : $f[7],
		$strand eq '+' ? $f[7] : $f[6],
		$f[-1],
		$strand,
		'.',
		$id,
	;
}
