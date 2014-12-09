#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use File::Basename;

my $d = { };

# parse files and make data structure
while (<>) {
	s/\s*$//;
	my $id = basename $ARGV;
	$id =~ s/\.stats\.txt$//;
	if (/^#/) {
		if (/: /) {
			my @f = split /\s*:\s+/, $_;
			$f[0] =~ s/^# //;
			$d->{$id}->{$f[0]} = $f[1];
		}
	}
	else {
		my @f = split;
		if ($f[0] eq 'all') { 
			$d->{$id}->{$f[4]} = $f[5];
		}
	}
}

my @fields = (
	'Organism name',
	'Shorthand',
	'GenBank Assembly ID',
	'RefSeq Assembly ID',
	'BioSample',
	'Taxid',
	'Date',
	'Submitter',
	'Release type',
	'Assembly Name',
	'Assembly type',
	'Assembly level',
	'Genome representation',
	'total-length',
	'total-gap-length',
	'spanned-gaps',
	'unspanned-gaps',
	'top-level-count',
	'contig-count',
	'contig-N50',
	'scaffold-count',
	'scaffold-L50',
	'scaffold-N50',
	'scaffold-N75',
	'scaffold-N90',
	'molecule-count',
	'region-count',
);

# formats
my $rowfmt = "%s\t" x scalar @fields;
my $urlfmt = "ftp://ftp.ncbi.nlm.nih.gov/genomes/all/%s_%s/%s_%s_genomic.fna.gz";

printf $rowfmt . "%s\t", @fields, 'URL';
print "\n";

while (my ($id, $props) = each %$d) {
	# remove whitespace from IDs and construct the taxon shorthand
	$props->{'GenBank Assembly ID'} =~ s/ .+$//;
	$props->{'RefSeq Assembly ID'} =~ s/ .+$// if defined $props->{'RefSeq Assembly ID'};
	$props->{'Assembly Name'} =~ s/\s+/_/g;
	my ($gen, $spec) = split ' ', $props->{'Organism name'}, 2;
	$props->{'Shorthand'} = lc(substr($gen, 0, 1) . substr($spec, 0, 4));

	# tabular output
	printf $rowfmt, map { $props->{$_} || '' } @fields;
	
	# also print URL
	# special case for Locusta migratoria
	if ($props->{'Shorthand'} eq 'lmigr') {
		print 'LOCUSTA MIGRATORIA EXISTS ONLY AS A WGS PROJECT AT http://www.ncbi.nlm.nih.gov/Traces/wgs/?val=AVCP01#contigs';
	}
	else {
		printf $urlfmt, $id, $props->{'Assembly Name'}, $id, $props->{'Assembly Name'};
	}
	print "\n";
}
