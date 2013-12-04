#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use Seqload::Fasta;
use File::Spec;
use File::Basename;
use IO::File;

my $infa = shift @ARGV or die "Usage: $0 INFILE_A INFILE_B\n";
my $infb = shift @ARGV or die "Usage: $0 INFILE_A INFILE_B\n";

# inf a must be the transcriptome file
my $infh = Seqload::Fasta->open($infa);

my $tr = {};

while (my ($h, $s) = $infh->next_seq()) {
	$h =~ /^(FBtr\d+)\b/;
	my $trid = $1;
	$tr->{$trid} = $s;
}

undef $infh;

$infh = Seqload::Fasta->open($infb);

my $pp = {};

while (my ($h, $s) = $infh->next_seq()) {
	$h =~ /^DMELA (FBpp\d+)\b/;
	my $ppid = $1;
	$h =~ /parent=FBgn\d+,(FBtr\d+);/;
	my $trid = $1;
	$pp->{$trid} = {'id' => $ppid, 'seq' => $s};
}

undef $infh;

my $trfh = IO::File->new(File::Spec->catfile('corresp-' . basename($infa)), 'w');
my $ppfh = IO::File->new(File::Spec->catfile('corresp-' . basename($infb)), 'w');

while (my $id = each %$tr) {
	printf "%s -> %s\n", $id, $pp->{$id}->{'id'};
	printf $trfh ">%s %s\n%s\n", $pp->{$id}->{'id'}, 'dbxref=' . $id, $tr->{$id};
	printf $ppfh ">%s\n%s\n", $pp->{$id}->{'id'}, $pp->{$id}->{'seq'};
}

undef $trfh;
undef $ppfh;
