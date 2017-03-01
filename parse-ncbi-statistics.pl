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
	$id =~ s/_assembly_stats\.txt$//;
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
	'group',
	'Infraspecific name',
	'GenBank assembly accession',
	'RefSeq assembly accession',
	'RefSeq assembly and GenBank assemblies identical',
	'BioSample',
	'Taxid',
	'Date',
	'Submitter',
	'Release type',
	'Assembly name',
	'Assembly type',
	'Assembly level',
	'Genome representation',
	'WGS project',
	'Assembly method',
	'Genome coverage',
	'Sequencing technology',
	'RefSeq category',
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


# table header
printf $rowfmt . "%s\n", @fields, 'URL';

while (my ($id, $props) = each %$d) {
	# remove whitespace from IDs and construct the taxon shorthand
	$props->{'GenBank assembly accession'} =~ s/ .+$// if defined $props->{'GenBank assembly accession'};
	$props->{'RefSeq assembly accession'} =~ s/ .+$// if defined $props->{'RefSeq assembly accession'};
	$props->{'Assembly name'} =~ s/\s+/_/g;
	my ($gen, $spec, $rest) = split ' ', $props->{'Organism name'}, 3;
	$props->{'Organism name'} = join ' ', $gen, $spec;
	$rest =~ s/\(|\)//g;
	$props->{'group'} = $rest;
	$props->{'Shorthand'} = lc(substr($gen, 0, 1) . substr($spec, 0, 4));

	# tabular output
	printf $rowfmt, map { $props->{$_} || '' } @fields;

	# also construct and print URL
	printf "ftp://ftp.ncbi.nlm.nih.gov/genomes/all/%s/%s/%s/%s/%s/%s_genomic.fna.gz",
		substr($id, 0, 3),
		substr($id, 4, 3),
		substr($id, 7, 3),
		substr($id, 10, 3),
		$id,
		$id,
	;

	# end of line
	print "\n";
}
