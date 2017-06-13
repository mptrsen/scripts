#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use File::Basename;

# Parse NCBI assembly statistics files and produce a tab-separated table
# Input: text files from NCBI
# Output: tab-separated table (on stdout)


# the data structure will be a hash of hashes, with the primary key being the
# assembly accession; secondary keys will be assembly metadata and properties
my $d = { };

# parse files and make data structure
while (<>) {
	s/\s*$//; # remove trailing whitespace
	my $id = basename $ARGV; # construct ID from file name
	$id =~ s/_assembly_stats\.txt$//; # remove file name suffix from ID
	if (/^#/) { # assembly metadata: IDs, name, submitter, method, etc.
		if (/: /) {
			my @f = split /\s*:\s+/;
			$f[0] =~ s/^# //; # remove leading '#' from field name
			$d->{$id}->{$f[0]} = $f[1];
		}
	}
	else { # assembly statistics; these have five columns
		my @f = split;
		if ($f[0] eq 'all') { 
			$d->{$id}->{$f[4]} = $f[5];
		}
	}
}

# these are the interesting fields
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

while (my ($id, $props) = each %$d) {
	# construct the taxon shorthand
	my ($gen, $spec) = split ' ', $props->{'Organism name'}, 2;
	$props->{'Shorthand'} = lc(substr($gen, 0, 1) . substr($spec, 0, 4));

	# print all fields in tab-separated format, empty string if undefined
	printf $rowfmt, map { $props->{$_} || '' } @fields;

	# also construct and print URL from assembly accession
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
		$props->{'Assembly name'},
		$id,
		$props->{'Assembly name'},
	;

	# end of line
	print "\n";
}
