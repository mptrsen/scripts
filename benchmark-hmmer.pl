#!/usr/bin/perl
use strict;
use warnings;

use Benchmark;

my ($db, $blastdb, $query);
if (scalar @ARGV == 3) { ($db, $blastdb, $query) = @ARGV } 
else { die "gimme 3 args!\n" }

my @blastcmd = qq(blastp -out /dev/null -outfmt 6 -db $blastdb -query $query);
my @psiblastcmd = qq(psiblast -out /dev/null -outfmt 6 -db $blastdb -query $query);
my @phmmercmd = qq(phmmer -o /dev/null --tblout /dev/null $query $db);
my @jackhmmercmd = qq(jackhmmer -o /dev/null --tblout /dev/null $query $db);

my $bench = timethese(1000, {
	'blastp' => sub { system(@blastcmd) },
	'phmmer' => sub { system(@phmmercmd) },
	'psiblast' => sub { system(@psiblastcmd) },
	'jackhmmer' => sub { system(@jackhmmercmd) }
	}
);
