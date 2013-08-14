#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use File::Spec;

# argument sorting
my $fn = shift @ARGV or die "Gimme a file!\n";
my $swissprot = shift @ARGV or die "Gimme two files!\n";
my $dir = shift @ARGV or die "Gimme two files and a dir!\n";
-d $dir or die "Fatal: not a directory: $dir\n";


# read the swissprot fasta file, store sequences in a hash
# the Seqload::Fasta module simplifies reading Fasta files, see below
my $ffh = Seqload::Fasta->open($swissprot);
my $seq_of = { };
while (my ($h, $s) = $ffh->next_seq()) {
	$seq_of->{$h} = $s;
}
undef $ffh;

open my $fh, '<', $fn;

while (<$fh>) {
	# $. is the current line number in the filehandle that we read from
	if ($. == 1 and not /^SampleAl/) { die "Invalid file, must start with 'SampleAl'\n" }
	next unless /Alignment/;
	# this is a complicated regex, using /x to explain inline
	/Alignment\(Sequence\(AC\('
		(\w+)		# the first AC -> $1
		'\)\)(\[
		(\d+)		# start of the first sequence -> $3
		\.\.
		(\d+)		# end of the first seq -> $4
		\])?,Sequence\(AC\('
		(\w+)		# second AC -> $5
		'\)\)(\[
		(\d+)		# start of the second seq -> $7
		\.\.
		(\d+)		# end of the second seq -> $8
		)?
	/x;

	unless (exists $seq_of->{$1} and exists $seq_of->{$5}) {
		print and 
		die "Fatal: sequence $1 or $5 does not exist in Fasta file $swissprot!\n";
	}

	# open new fasta file for the alignment
	my $af = File::Spec->catfile($dir, sprintf("%03d", $.) . '.fa');
	open my $afh, '>', $af;

	# coordinates for both first and second seq are present
	if (defined $2 and defined $6) {
		printf "%d: %s (%d) [%d:%d], %s (%d) [%d:%d]\n",
			$.,	# current line, i.e., alignment #
			$1,	# first AC
			length $seq_of->{$1},	# length of the first seq
			$3,	# start of the first seq
			$4,	# end of the first seq
			$5,	# second AC
			length $seq_of->{$5},	# length of the second seq
			$7,	# start of the first seq
			$8,	# end of the first seq
		;
		printf $afh ">%s\n%s\n>%s\n%s\n",
			$1,
			substr($seq_of->{$1}, $3-1, $4-$3),
			$5,
			substr($seq_of->{$5}, $7-1, $8-$7),
		;
			
	}
	# coordinates for the first seq is missing
	elsif (defined $2) {
		printf "%d: %s (%d) [%d:%d], %s (%d) [:]\n",
			$.,	# current line
			$1,	# first AC
			length $seq_of->{$1},
			$3,	# start of the first seq
			$4,	# end of the first seq
			$5,	# second AC
			length $seq_of->{$5},
		;
		printf $afh ">%s\n%s\n>%s\n%s\n",
			$1,
			substr($seq_of->{$1}, $3-1, $4-$3),
			$5,
			$seq_of->{$5},
		;
	}
	# coordinates for the second seq is missing
	elsif (defined $6) {
		printf "%d: %s (%d) [:], %s (%d) [%d:%d]\n",
			$.,	# current line
			$1,	# first AC
			length $seq_of->{$1},
			$5,	# second AC
			length $seq_of->{$5},
			$7,	# start of the second seq
			$8,	# end of the second seq
		;
		printf $afh ">%s\n%s\n>%s\n%s\n",
			$1,
			$seq_of->{$1},
			$5,
			substr($seq_of->{$5}, $7-1, $8-$7),
		;
	}
	# coordinates for both seqs are missing
	else {
		printf "%d: %s (%d) [:], %s (%d) [:]\n",
			$.,	# current line
			$1,	# first AC
			length $seq_of->{$1},
			$5,	# second AC
			length $seq_of->{$5},
		;
		printf $afh ">%s\n%s\n>%s\n%s\n",
			$1,
			$seq_of->{$1},
			$5,
			$seq_of->{$5},
		;
	}
	close $afh;
}

close $fh;


package Seqload::Fasta;
# Documentation before the code#{{{
=head1 NAME

Seqload::Fasta

=head1 DESCRIPTION

A library for handling FASTA sequences in an object-oriented fashion. 
Incompatibility with BioPerl is intentional.

=head1 SYNOPSIS

  use Seqload::Fasta qw(fasta2csv check_if_fasta);
  
  # test whether this is a valid fasta file
  check_if_fasta($filename) or die "Not a valid fasta file: $filename\n";

  # open the file, return fasta file object
  my $file = Seqload::Fasta->open($filename);
  
  # loop through the sequences
  while (my ($hdr, $seq) = $file->next_seq) {
    print $hdr . "\n" . $seq . "\n";
  }

  # just undef the object, the destructor closes the file
  undef($file)

  # convert a fasta file to a csv file
  fasta2csv($fastafile, $csvfile);


=head1 METHODS

=head2 open(FILENAME)

Opens a fasta file. Returns a sequence database object.

=head2 next_seq

Returns the next sequence in a sequence database object as an array (HEADER,
SEQUENCE). Note that the '>' character is truncated from the header.

  ($header, $sequence) = $file->next_seq;

=head1 FUNCTIONS

=head2 fasta2csv($fastafile, $csvfile)

Converts a fasta file into a csv file where each line consists of
'HEADER,SEQUENCE'. Manages opening, parsing and closing of the files, no
additional file handles necessary.

=head2 check_if_fasta($file)

Checks whether or not the specified file is a valid fasta file (i.e., starts with a header line). Returns 0 if not and 1 otherwise.

=cut#}}}
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
	# here is the trick that makes this work
  local $/ = "\n>"; # change the line separator
  return unless defined(my $item = readline($fh));  # read the line(s)
  chomp $item;
  
  if ($. == 1 and $item !~ /^>/) {  # first line is not a header
    croak "Fatal: " . $self->{'filename'} . "is not a FASTA file: Missing descriptor line\n";
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

# Convert a fasta file to a csv file the easy way
# Usage: Seqload::Fasta::fasta2csv($fastafile, $csvfile);
sub fasta2csv {
  my $fastafile = shift;
  my $csvfile = shift;

  my $fastafh = Seqload::Fasta->open($fastafile);
  CORE::open(my $outfh, '>', $csvfile)
    or confess "Fatal: Could not open $csvfile\: $!\n";
  while (my ($hdr, $seq) = $fastafh->next_seq) {
		$hdr =~ s/,/_/g;	# remove commas from header, they mess up a csv file
    print $outfh $hdr . ',' . $seq . "\n"
			or confess "Fatal: Could not write to $csvfile\: $!\n";
  }
  CORE::close $outfh;
  $fastafh->close;

  return 1;
}

# validates a fasta file by looking at the FIRST (header, sequence) pair
# arguments: scalar string path to file
# returns: true on validation, false otherwise
sub check_if_fasta {
	my $infile = shift;
	my $infh = Seqload::Fasta->open($infile);
	my ($h, $s) = $infh->next_seq() or return 0;
	return 1;
}

# return true
'This line intentionally left true';
