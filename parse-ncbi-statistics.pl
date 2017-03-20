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
	'GenBank Assembly Accession',
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

printf $rowfmt . "%s\n", @fields, 'URL';

while (my ($id, $props) = each %$d) {
	# remove whitespace from IDs and construct the taxon shorthand
	$props->{'GenBank Assembly ID'} =~ s/ .+$// if defined $props->{'GenBank Assembly ID'};
	$props->{'RefSeq Assembly ID'} =~ s/ .+$// if defined $props->{'RefSeq Assembly ID'};
	$props->{'GenBank Assembly Accession'} =~ s/ .+$// if defined $props->{'GenBank Assembly Accession'};
	$props->{'Assembly Name'} =~ s/\s+/_/g if defined $props->{'Assembly Name'};
	my ($gen, $spec) = split ' ', $props->{'Organism name'}, 2;
	$props->{'Shorthand'} = lc(substr($gen, 0, 1) . substr($spec, 0, 4));

	# tabular output
	printf $rowfmt, map { $props->{$_} || '' } @fields;

	# also construct and print URL
	my $url_dir1 = substr($id, 0, 3);
	my $url_dir2 = substr($id, 4, 3); # skip the underscore
	my $url_dir3 = substr($id, 7, 3);
	my $url_dir4 = substr($id, 10, 3);
	#  example:   ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/000/516/895/GCA_000516895.1_LocustGenomeV1/GCA_000516895.1_LocustGenomeV1_genomic.fna.gz
	my $urlfmt = "ftp://ftp.ncbi.nlm.nih.gov/genomes/all/%s/%03d/%03d/%03d/%s_%s/%s_%s_genomic.fna.gz";
	printf $urlfmt,
		$url_dir1,
		$url_dir2,
		$url_dir3,
		$url_dir4,
		$id,
		$props->{'Assembly Name'},
		$id,
		$props->{'Assembly Name'},
	;

	# end of line
	print "\n";
}
