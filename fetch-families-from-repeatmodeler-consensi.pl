#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use File::Spec::Functions;
use File::Basename;
use Data::Dumper;
use Getopt::Long;

=head1 NAME

fetch-families-from-repeatmodeler-consensi.pl -- Build profile HMMs from RepeatModeler families

=head1 SYNOPSIS

B<fetch-families-from-repeatmodeler-consensi.pl> [OPTIONS] [--outdir Output_dir] --rmdir RModeler_dir

=head1 DESCRIPTION

Reads a consensi.fa.classified file from RepeatModeler, fetches the sequences
from the corresponding RM output directory, makes a multiple sequence alignment
for each family, and constructs a HMM for each family for future searching.

Mandatory parameter: Path to RModeler output directory

=head1 OPTIONS

=over

=item B<--species> Species_name

Specify species name. Genus and species can be separated by underscore or space
(in that case, you need quotes around it). Used to construct accession.
Mandatory.

=item B<--rmdir> [pathspec]

Specify path to RepeatModeler output directory (usually ends in something like
"RM_26226.TueDec230307382014"). Mandatory.

=item B<--ncpu> [N]

Use N CPU threads. Default: 1 thread.

=item B<--outdir> [pathspec]

Specify output directory. Default: current directory.

=item B<--path-to-linsi> [pathspec]

Specify path to B<linsi>, if not present in PATH. Default: "mafft".

=item B<--path-to-hmmbuild> [pathspec]

Specify path to B<hmmbuild>, if not present in PATH. Default: "hmmbuild".

=item B<--accession-prefix> [prefix]

Specify prefix to be used in HMM accession strings. Default: unset (no prefix, just 'rNfY')

=back

=head1 AUTHOR

Malte Petersen L<<mptrsen@uni-bonn.de>>

=head1 LICENSE

Copyright (c) 2017 Malte Petersen. Licensed under the GNU General Public
License (GPL) version 3. This is free software: you are free to change and
redistribute it. There is NO WARRANTY, to the extent permitted by law.


=cut

my $usage = "Usage: $0 [--ncpu N] [--outdir Output_dir] [options] --species Species_name --rmdir RModeler_dir\n";

my $outdir           = '.';
my $ncpu             = 1;
my $rmdir            = '';
my $linsi            = 'linsi';
my $hmmbuild         = 'hmmbuild';
my $species          = '';
my $accession_prefix = undef;
GetOptions(
	'outdir=s'           => \$outdir,
	'ncpu=i'             => \$ncpu,
	'rmdir=s'            => \$rmdir,
	'path-to-linsi=s'    => \$linsi,
	'path-to-hmmbuild=s' => \$hmmbuild,
	'species=s'          => \$species,
	'accession-prefix=s' => \$accession_prefix,
) or die "Error in command line arguments\n";
$rmdir   //= shift @ARGV or die $usage;
$species //= shift @ARGV or die $usage;

$species = Species->new($species);

# make sure paths exist where specified
-d $outdir or die "Output directory '$outdir' not found\n";
-d $rmdir or die "RModeler directory '$rmdir' not found\n";
system( "$linsi --help > /dev/null 2>&1" ) or die "linsi not found or not executable at '$linsi'\n";
system( "$hmmbuild --help > /dev/null 2>&1" ) or die "hmmbuild not found or not executable at '$hmmbuild'\n";

# find and load consensus sequences into memory
# (even though we only need the headers)
my $consensi_file = File::Spec->catfile($rmdir, 'consensi.fa.classified');
my $consensus_sequences = Seqload::Fasta::slurp_fasta($consensi_file);


# go through keys, parse round and family information, assign file paths to them
my $i = 0;
my $n = scalar keys %$consensus_sequences;
foreach my $header (sort { $a cmp $b } keys %$consensus_sequences) {
	$i++;
	my $family = Family->new($rmdir, $header);
	$family->accession( { prefix => $accession_prefix } );
	printf "Making MSA for round %d, family %d (%s) from file %s (%d of %d)\n",
		$family->round(),
		$family->family(),
		$family->name(),
		$family->file(),
		$i,
		$n,
	;
	$family->make_alignment( $outdir, $linsi, $ncpu );
	printf "MSA file: %s\n", $family->msafile();
	print "Making HMM\n";
	$family->make_hmm( $outdir, $hmmbuild, $ncpu );
	printf "HMM file: %s\n", $family->hmmfile();
	$family->add_accession_to_hmm();
	print "Added accession ", $family->accession(), "\n";
	print "-------------------\n";
}

package Family;

=head1 NAME

Family

=head1 DESCRIPTION

Handles repeat family identification from RepeatModeler consensi.fa.classified
files. Can find the corresponding files from a repeatmodeler output directory
by parsing the headers.

Constructs MSA and HMM files from the sequences using mafft and hmmbuild,
respectively. Can additionally add an accession number to the resulting HMM
files.

=cut

use strict;
use warnings;
use autodie;
use File::Basename;
use File::Spec::Functions;
use Carp;
use Tie::File;

sub new {
	my $class = shift;
	my $rmdir = shift || confess;
	my $hdr = shift || confess;
	my $self = parse_header($hdr);
	bless $self, $class;
	$self->file( File::Spec->catfile($rmdir, 'round-' . $self->round(), 'family-' . $self->family() . '.fa') );
	return $self;
}

sub parse_header {
	my $hdr = shift @_;
	$hdr =~ s/ .+$//; # remove everything after the first part
	my ($rndfam, $name) = split '#', $hdr;
	my ($rnd, $fam) = split '_', $rndfam;
	$rnd =~ s/^rnd-//; # isolate the number
	$fam =~ s/^family-//; # isolate the number
	my $data = {
		'name'   => $name,
		'round'  => $rnd,
		'family' => $fam,
		'header' => $hdr,
	};
	return $data;
}

sub output_directory {
	my $self = shift;
	return $self->{'output_directory'} if defined $self->{'output_directory'};
	$self->{'output_directory'} = shift || confess;
}

sub file {
	my $self = shift;
	return $self->{'file'} if defined $self->{'file'};
	$self->{'file'} = shift || confess;
}

sub name {
	my $self = shift;
	return $self->{'name'} if defined $self->{'name'};
	$self->{'name'} = shift || confess;
}

sub round {
	my $self = shift;
	return $self->{'round'} if defined $self->{'round'};
	$self->{'round'} = shift || confess;
}

sub family {
	my $self = shift;
	return $self->{'family'} if defined $self->{'family'};
	$self->{'family'} = shift || confess;
}

sub header {
	my $self = shift;
	return $self->{'header'} if defined $self->{'header'};
	$self->{'header'} = shift || confess;
}

sub msafile {
	my $self = shift;
	return $self->{'msafile'} if defined $self->{'msafile'};
	$self->{'msafile'} = shift || confess;
}

sub hmmfile {
	my $self = shift;
	return $self->{'hmmfile'} if defined $self->{'hmmfile'};
	$self->{'hmmfile'} = shift || confess;
}

# returns a string based on round and family information
sub file_basename {
	my $self = shift;
	return catfile('round-' . $self->round() . '_family-' . $self->family());
}

# infers a multiple sequence alignment (MSA) using MAFFT L-INS-i and returns the path to the MSA file
sub make_alignment {
	my $self = shift;
	my $outdir = shift || confess;
	my $linsi = shift || confess;
	my $ncpu = shift || confess;
	my $inf = $self->file();
	my $outf = catfile($outdir, $self->file_basename() . '.afa');
	system("$linsi --thread $ncpu '$inf' > '$outf' 2> /dev/null") and confess "Fatal: mafft failed: $!";
	$self->msafile($outf);
	return $self->msafile();
}

# generates a HMM profile and returns the path to it
sub make_hmm {
	my $self = shift @_;
	my $outdir = shift || confess;
	my $hmmbuild = shift || confess;
	my $ncpu = shift || confess;
	my $inf = $self->msafile();
	my $name = $self->header();
	my $outf = catfile($outdir, $self->file_basename() . '.hmm');
	system("$hmmbuild --cpu $ncpu -n '$name' --informat afa '$outf' '$inf' 2> /dev/null") and confess "Fatal: hmmbuild failed: $!";
	$self->hmmfile($outf);
	return $self->hmmfile();
}

# constructs accession using species shorthand, round and family information
sub accession {
	my $self = shift;
	my $opts = shift;
	return $self->{'accession'} if defined $self->{'accession'};
	my $prefix = $opts->{'prefix'};
	if (defined $prefix) {
		$self->{'accession'} = $prefix . '_r' . $self->round() . 'f' . $self->family();
	}
	else {
		$self->{'accession'} = 'r' . $self->round() . 'f' . $self->family();
	}
}

# adds accession to the HMM file
sub add_accession_to_hmm {
	my $self = shift;
	tie my @model_file, 'Tie::File', $self->hmmfile();
	return if grep { /^ACC/ } @model_file; # in case this has been modified before
	splice @model_file, 2, 0, 'ACC   ' . $self->accession();
	untie @model_file;
}

package Species;

=head1 NAME

Species

=head1 SYNOPSIS

    my $species = Species->new("Homo sapiens");
		print $species->genus, "\n";
		print $species->species, "\n";
		print $species->shorthand, "\n"; # 1:4 lowercase abbreviation

=head1 DESCRIPTION

Handles species name formatting etc.

=cut

use strict;
use warnings;
use Carp;

sub new {
	my $class = shift;
	my $species_string = shift;
	my ($genus, $species) = split / |_/, $species_string;
	my $self = {
		'species' => $species,
		'genus'   => $genus,
	};
	return bless $self, $class;
}

sub genus {
	my $self = shift;
	return $self->{'genus'} if defined $self->{'genus'};
	$self->{'genus'} = shift || confess;
}

sub species {
	my $self = shift;
	return $self->{'species'} if defined $self->{'species'};
	$self->{'species'} = shift || confess;
}

sub full_name {
	my $self = shift;
	return $self->genus() . '_' . $self->species();
}

sub shorthand {
	my $self = shift;
	return $self->{'shorthand'} if defined $self->{'shorthand'};
	if ($self->species()) {
		$self->{'shorthand'} = lc substr($self->genus(), 0, 1) . lc substr($self->species(), 0, 4);
	}
	else { # if there was no genus/species separator, we only have genus
		$self->{'shorthand'} = $self->genus();
	}
	return $self->{'shorthand'};
}

package Seqload::Fasta;
use strict;
use warnings;
use Carp;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw( fasta2csv check_if_fasta );

# Constructor. Returns a sequence database object.
sub open {
	my ($class, $filename) = @_;
	open (my $fh, '<', $filename)
		or confess "Fatal: Could not open $filename\: $!\n";
	my $self = {
		'filename' => $filename,
		'fh'       => $fh
	};
	bless($self, $class);
	return $self;
}

# Returns the next sequence as an array (hdr, seq). 
# Useful for looping through a seq database.
sub next_seq {
	my $self = shift;
	my $fh = $self->{'fh'};
	# this is the trick that makes this work
	local $/ = "\n>"; # change the line separator
	return unless defined(my $item = readline($fh));  # read the line(s)
	chomp $item;
	if ($. == 1 and $item !~ /^>/) {  # first line is not a header
		confess "Fatal: " . $self->{'filename'} . " is not a FASTA file: Missing descriptor line\n";
	}
	# remove the '>'
	$item =~ s/^>//;
	# split to a maximum of two items (header, sequence)
	my ($hdr, $seq) = split(/\n/, $item, 2);
	$hdr =~ s/\s+$//;	# remove all trailing whitespace
	$seq =~ s/>//g if defined $seq;
	$seq =~ s/\s+//g if defined $seq; # remove all whitespace, including newlines
	return($hdr, $seq);
}

# Closes the file and undefs the database object.
sub close {
	my $self = shift;
	my $fh = $self->{'fh'};
	my $filename = $self->{'filename'};
	close($fh) or carp("Warning: Could not close $filename\: $!\n");
	undef($self);
}

# Destructor. This is called when you undef() an object
sub DESTROY {
	my $self = shift;
	$self->close;
}
#
# loads a Fasta file into a hashref
# arguments: scalar string path to file
# returns: hashref (header => sequence)
sub slurp_fasta {
	my $infile = shift;
	my $sequences = {};
	my $infh = Seqload::Fasta->open($infile);
	while (my ($h, $s) = $infh->next_seq()) {
		$sequences->{$h} = $s;
	}
	undef $infh;
	return $sequences;
}
