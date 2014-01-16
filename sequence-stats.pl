#!/usr/bin/perl
use strict;
use warnings;
use autodie;

my $usage = "Usage: $0 INFILE\n";
my $inf = shift @ARGV or die $usage;

my $total_length = 0;
my $n50 = 0;
my $n90 = 0;
my $perc_A = 0;
my $perc_T = 0;
my $perc_C = 0;
my $perc_G = 0;
my $n_A = 0;
my $n_T = 0;
my $n_C = 0;
my $n_G = 0;
my $n_500plus = 0;
my $n_1k_plus = 0;
my $n_10k_plus = 0;
my $n_100k_plus = 0;
my $n_1m_plus = 0;
my $shortest = 0;
my $longest = 0;

my $fh = Seqload::Fasta->open($inf);

my @seqs = ();

while (my ($h, $s) = $fh->next_seq()) {
	my $len = length $s;
	$total_length += $len;
	# categorize by length
	if    ($len > 1_000_000)  { $n_1m_plus++   }
	elsif ($len > 100_000)    { $n_100k_plus++ }
	elsif ($len > 10_000)     { $n_10k_plus++  }
	elsif ($len > 1000)       { $n_1k_plus++   }
	elsif ($len > 500)        { $n_500plus++   }
	# count bases
	$n_A++ while $s =~ m/a/gi;
	$n_T++ while $s =~ m/t/gi;
	$n_C++ while $s =~ m/c/gi;
	$n_G++ while $s =~ m/g/gi;
	push @seqs, $s;
}

# exit if file contains zero sequences
if (scalar @seqs == 0) { 
	print "no sequences\n";
	exit;
}

# calculate percentages
$perc_A = $n_A / $total_length;
$perc_T = $n_T / $total_length;
$perc_C = $n_C / $total_length;
$perc_G = $n_G / $total_length;

@seqs = sort { length $a <=> length $b } @seqs;

my $tmp_len = 0;

$longest = $shortest = length $seqs[0];

foreach my $s (@seqs) {
	my $len = length $s;
	# longest and shortest
	$shortest = $len if $len < $shortest;
	$longest = $len if $len > $longest;
	# n90
	if ($n90 == 0 and $tmp_len + $len > $total_length * 0.9) {
		$n90 = $tmp_len;
	}
	# n50
	elsif ($n50 == 0 and $tmp_len + $len > $total_length/2) {
		$n50 = $tmp_len;
	}
	$tmp_len += length $s;
}

# report
printf "sequences: %d\n" .
       "total_length: %d\n" .
			 "longest: %d\n" .
			 "shortest: %d\n" .
			 "n50: %d\n" .
			 "n90: %d\n" .
			 "seqs > 500 nt: %d\n" .
			 "seqs > 1k nt: %d\n" .
			 "seqs > 10k nt: %d\n" .
			 "seqs > 100k nt: %d\n" .
			 "seqs > 1M nt: %d\n" .
			 "perc A: %.2f\n" .
			 "perc T: %.2f\n" .
			 "perc C: %.2f\n" .
			 "perc G: %.2f\n" .
			 '',
			 scalar @seqs,
			 $total_length,
			 $longest,
			 $shortest,
			 $n50,
			 $n90,
			 $n_500plus,
			 $n_1k_plus,
			 $n_10k_plus,
			 $n_100k_plus,
			 $n_1m_plus,
			 $perc_A,
			 $perc_T,
			 $perc_C,
			 $perc_G,
			 ;


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

