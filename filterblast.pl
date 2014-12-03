#!/opt/perl/bin/perl

# filter a BLAST result file in format 7 (tab-delimited, standard)
# the fields are as follows:
# $1        $2          $3      $4          $5    $6         $7        $8      $9        $10     $11     $12
# query id, subject id, %ident, aln length, mism, gap opens, q. start, q. end, s. start, s. end, evalue, bit score

use strict;
use warnings;
use autodie;

my @fields;
my $ident;
my $eval;
my $len;
my $qs;
my $qe;
my $ss;
my $se;
my $s_revsd;
my $q_revsd;
my $have_header;

while (<>) {
	# get the first header, skip all following
	if (/^#/) {
		if ($have_header) { next }
		print;
		if (/^# Fields/) { $have_header = 1 }
		next;
	}
	@fields = split /\t/;
	$ident  = $fields[2];
	$eval   = $fields[10];
	$len    = $fields[3];

	# are query or target reversed?
	if ($fields[6] < $fields[7]) {
		$qstart  = $fields[6];
		$qend = $fields[7];
		$q_revsd = 0;
	} else {
		$qstart  = $fields[7];
		$qend = $fields[6];
		$q_revsd = 1;
	}
	if ($fields[8] < $fields[9]) {
		$sstart  = $fields[8];
		$send = $fields[9];
		$s_revsd = 0;
	} else {
		$sstart  = $fields[9];
		$send = $fields[8];
		$s_revsd = 1;
	}

	# skip all where query overlaps target, in either direction
	if    ( $q_revsd && $qend   <= $send   && $qstart >= $sstart ) { next }
	elsif ( $s_revsd && $qstart <= $sstart && $qend   >= $send   ) { next }
	elsif (             $qstart <= $send   && $qend   >= $sstart ) { next }

	# print where identity > 97% and eval < 1e-3 and len >= 100
	if ( $ident > 97 && $eval < 0.001 && $len >= 100 ) { print }

	if ( $. % 100_000 == 0 ) { print STDERR "seen $. rows\n" }
}
