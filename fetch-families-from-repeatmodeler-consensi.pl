#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use File::Spec::Functions;
use File::Basename;
use Data::Dumper;
use Getopt::Long;

# Reads a consensi.fa.classified file from RepeatModeler,
# fetches the sequences from the RM output directory,
# makes a multiple sequence alignment for each family,
# constructs a HMM for each family for future searching.
#
# Parameters: path to RModeler output directory

my $usage = "Usage: $0 [--ncpu N] [--outdir Output_dir] RModeler_dir\n";

my $outdir;
my $ncpu;
my $rmdir;
my $opts = GetOptions( "outdir=s" => \$outdir, 'ncpu=i' => \$ncpu, 'rmdir=s' => \$rmdir ) or die "Error in command line arguments\n";
$outdir //= '.';
$ncpu   //= 1;
$rmdir  //= shift @ARGV or die $usage;

# find and load consensus sequences into memory
# (even though we only need the headers)
my $consensi_file = File::Spec->catfile($rmdir, 'consensi.fa.classified');
my $consensus_sequences = Seqload::Fasta::slurp_fasta($consensi_file);

# go through keys, parse round and family information, assign file paths to them
foreach my $header (sort { $a cmp $b } keys %$consensus_sequences) {
	my $family = Family->new($rmdir, $header);
	printf "Making MSA for round %d, family %d (%s) from file %s\n", $family->round(), $family->family(), $family->name(), $family->file();
	$family->make_alignment( $outdir, $ncpu );
	printf "MSA file: %s\n", $family->msafile();
	print "Making HMM\n";
	$family->make_hmm( $outdir, $ncpu );
	printf "HMM file: %s\n", $family->hmmfile();
	print "-------------------\n";
}

package Family;

use strict;
use warnings;
use autodie;
use File::Basename;
use File::Spec::Functions;
use Carp;

sub new {
	my $class = shift;
	my $rmdir = shift || croak;
	my $hdr = shift || croak;
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
	$self->{'output_directory'} = shift;
}

sub file {
	my $self = shift;
	return $self->{'file'} if defined $self->{'file'};
	$self->{'file'} = shift || croak;
}

sub name {
	my $self = shift;
	return $self->{'name'} if defined $self->{'name'};
	$self->{'name'} = shift || carp;
}

sub round {
	my $self = shift;
	return $self->{'round'} if defined $self->{'round'};
	$self->{'round'} = shift || carp;
}

sub family {
	my $self = shift;
	return $self->{'family'} if defined $self->{'family'};
	$self->{'family'} = shift || carp;
}

sub header {
	my $self = shift;
	return $self->{'header'} if defined $self->{'header'};
	$self->{'header'} = shift || carp;
}

sub msafile {
	my $self = shift;
	return $self->{'msafile'} if defined $self->{'msafile'};
	$self->{'msafile'} = shift || carp;
}

sub hmmfile {
	my $self = shift;
	return $self->{'hmmfile'} if defined $self->{'hmmfile'};
	$self->{'hmmfile'} = shift || carp;
}

sub make_alignment {
	my $self = shift;
	my $outdir = shift || croak;
	my $ncpu = shift || croak;
	my $inf = $self->file();
	my $outf = catfile($outdir, basename($inf, '.fa') . '.afa');
	system("linsi --thread $ncpu '$inf' > '$outf' 2> /dev/null") and die;
	$self->msafile($outf);
	return $self->msafile();
}

sub make_hmm {
	my $self = shift @_;
	my $outdir = shift || croak;
	my $ncpu = shift || croak;
	my $inf = $self->msafile();
	my $name = $self->header();
	my $outf = catfile($outdir, basename($inf) . '.hmm');
	system("hmmbuild --cpu $ncpu -n '$name' --informat afa '$outf' '$inf' 2> /dev/null") and die;
	$self->hmmfile($outf);
	return $self->hmmfile();
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
		croak "Fatal: " . $self->{'filename'} . " is not a FASTA file: Missing descriptor line\n";
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
