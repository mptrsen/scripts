#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use File::Spec;

my $usage = "Usage: $0 FILTERFILE FASTAFILE\n  - FILTERFILE must contain taxon shorthands only, separated by newlines\n  - FASTAFILE must be a valid file from OrthoDB version 5 or 6\n";

# manage argument list, exit with help message if requested
my $wlf = shift @ARGV;
my $faf = shift @ARGV;
if (!defined $wlf or $wlf eq '-h' or $wlf eq '--help') { print $usage and exit }
unless ($wlf and $faf) { die $usage }
unless (-f $wlf and -f $faf) { die $usage  }

# read the filter word list file
my @shorthands = slurpwordlist($wlf);

# read the fasta file into memory
my $seqs = slurpfasta($faf);

# determine orthodb version
my $odbversion = 5;
my $nseqs = scalar keys %$seqs;
if ((grep {/^[A-Z]{5}/} keys %$seqs) == $nseqs) {
	$odbversion = 5;
}
elsif ((grep {/[A-Z]{5}$/} keys %$seqs) == $nseqs) {
	$odbversion = 6;
}
else {
	die "Fatal: wrong Fasta header format. File really from OrthoDB?\n";
}

# order the header fields according to the orthodb version, output
while (my ($h, $s) = each %$seqs) {
	my @fields = split /\s+/, $h;
	$fields[0] =~ s/:.*$//;
	if ($odbversion == 6) {
		if (grep { /$fields[-1]/ } @shorthands) {
			printf ">%s %s %s %s\n%s\n", $fields[-1], $fields[0], $fields[-2], $fields[1], $s;
		}
	}
	else {
		if (grep { /$fields[0]/ } @shorthands) {
			printf ">%s %s %s %s\n%s\n", @fields[0..3], $s;
		}
	}
}

# returns header->sequence hashref
# uses Seqload::Fasta
sub slurpfasta {
	my $f = shift;
	my $d = { };
	my $fh = Seqload::Fasta->open($f);
	while (my ($h, $s) = $fh->next_seq()) {
		$d->{$h} = $s;
	}
	return $d;
}

# returns list
sub slurpwordlist {
	open my $fh, '<', shift @_;
	my @ls = <$fh>;
	close $fh;
	chomp @ls;
	return @ls;
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
    die "Fatal: " . $self->{'filename'} . " is not a FASTA file: Missing descriptor line\n";
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

