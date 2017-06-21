#!/usr/bin/perl

# Parse NCBI assembly statistics files and produce a tab-separated table
# Input: text files from NCBI
# Output: tab-separated table (on stdout)

use strict;
use warnings;
use autodie;
use File::Basename;

# the data structure will be a hash of hashes, with the primary key being the
# assembly accession; secondary keys will be assembly metadata and properties
my $d = { };

# parse files and make data structure
while (<>) {
	s/\s*$//; # remove trailing whitespace
	my $acc = basename $ARGV; # take accession number from file name
	$acc =~ s/_assembly_stats\.txt$//; # remove file name suffix from accession
	if (/^#/) { # assembly metadata: IDs, name, submitter, method, etc.
		if (/: /) {
			my @f = split /\s*:\s+/;
			$f[0] =~ s/^# //; # remove leading '#' from field name
			$d->{$acc}->{$f[0]} = $f[1];
		}
	}
	else { # assembly statistics; these have six columns and we want the last two
		my @f = split;
		if ($f[0] eq 'all') { 
			$d->{$acc}->{$f[4]} = $f[5];
		}
	}
}

# these are the interesting fields, in order
my @fields = (
	'Organism name',
	'Shorthand',
	'RefSeq assembly accession',
	'GenBank assembly accession',
	'RefSeq assembly and GenBank assemblies identical',
	'WGS project',
	'BioProject',
	'BioSample',
	'Taxid',
	'Date',
	'Submitter',
	'Release type',
	'Assembly name',
	'Synonyms',
	'Assembly type',
	'Assembly level',
	'Genome representation',
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

# tab-separated table format according to number of fields
my $rowfmt = "%s\t" x scalar @fields;

# add URL column and print table header
printf $rowfmt . "%s\n", @fields, 'URL';

while (my ($acc, $props) = each %$d) {
	# construct a taxon shorthand
	my ($gen, $spec) = split ' ', $props->{'Organism name'}, 2;
	$props->{'Shorthand'} = lc(substr($gen, 0, 1) . substr($spec, 0, 4));

	# print all fields in tab-separated format, empty string if undefined
	printf $rowfmt, map { $props->{$_} // '' } @fields;

	# also construct and print URL from assembly accession
	# example:   ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/000/516/895/GCA_000516895.1_LocustGenomeV1/GCA_000516895.1_LocustGenomeV1_genomic.fna.gz
	my $urlfmt = "ftp://ftp.ncbi.nlm.nih.gov/genomes/all/%s/%03d/%03d/%03d/%s/%s_genomic.fna.gz";
	my $url_dir1 = substr($acc, 0, 3);
	my $url_dir2 = substr($acc, 4, 3); # skip the underscore
	my $url_dir3 = substr($acc, 7, 3);
	my $url_dir4 = substr($acc, 10, 3);
	printf $urlfmt,
		$url_dir1,
		$url_dir2,
		$url_dir3,
		$url_dir4,
		$acc,
		$acc,
	;

	# end of line
	print "\n";
}
