#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use Getopt::Long;

my $force  = 0;
my $nfiles = 0;
my $nseqs  = 0;
my $basename = 'sequences';

GetOptions( 'force|f' => \$force, 'nfiles=i' => \$nfiles, 'nseqs=i' => \$nseqs, 'basename=s' => \$basename ) or die ;

my $usage = "USAGE: $0 [OPTIONS] FASTAFILE [FASTAFILE FASTAFILE ...]\n\n";
$usage .= "Options:\n";
$usage .= "  --force : overwrite existing files\n";
$usage .= "  --nfiles N : split into N files\n";
$usage .= "  --nseqs N : split into files with N sequences each\n";
$usage .= "  --basename S : name the files S_1.fa, S_2.fa, ...\n";

if (scalar @ARGV == 0 or (!$nseqs and !$nfiles)) { print $usage and exit }

my $seqs = slurp_fasta_arrayref(shift @ARGV );

# read all seqs into one huge array
foreach my $file (@ARGV) {
	my $addtl_seqs = slurp_fasta_arrayref($file);
	push @$seqs, @$addtl_seqs;
}

die if scalar(@$seqs) % 2 != 0;


if ($nfiles) {
	my $fn_len = length $nfiles;
	my $n_sequences = int(scalar @$seqs / 2 / $nfiles);

	for (my $i = 1; $i <= $nfiles; $i++) {

		my $fn = sprintf "%s_%0${fn_len}d.fa", $basename, $i;

		if (-e $fn and not $force) { print "file $fn exists. Use --force to overwrite\n" and exit }

		open my $outfh, '>', $fn;
		
		for (my $j = 0; $j < $n_sequences; $j++) {
			my ($h, $s) = splice(@$seqs, 0, 2);
			printf $outfh ">%s\n%s\n", $h, $s;
		}
		printf "wrote %d sequences to file '%s'\n", $n_sequences, $fn;
		close $outfh;
	}
	# put the rest of the sequences into an overspill file
	my $fn = $basename . '_overspill.fa';
	my $n = 0;
	open my $outfh, '>', $fn;
	while (my ($h, $s) = splice(@$seqs, 0, 2)) {
		printf $outfh ">%s\n%s\n", $h, $s;
		$n++;
	}
	printf "wrote %d overspill sequence(s) to file '%s'\n", $n, $fn;
	close $outfh;
}

elsif ($nseqs) {
	my $n = 0;
	my $fn_len = int(scalar(@$seqs) / $nseqs);

	while (scalar @$seqs != 0) {
		$n++;
		my $c = 0;
		my $fn = sprintf "%s_%0${fn_len}d.fa", $basename, $n;

		if (-e $fn and not $force) { print "file $fn exists. Use --force to overwrite\n" and exit }

		open my $outfh, '>', $fn;

		while (my ($h, $s) = splice(@$seqs, 0, 2)) {
			printf $outfh ">%s\n%s\n", $h, $s;
			last unless ++$c < $nseqs;
		}

		close $outfh;

		printf "wrote %d sequences to file '%s'\n", $c, $fn;
	}
}


sub slurp_fasta_arrayref {
	my $infile = shift;
	my $sequences = [];
	my $infh = Seqload::Fasta->open($infile);
	while (my ($h, $s) = $infh->next_seq()) {
		push @$sequences, ($h, $s);
	}
	undef $infh;
	return $sequences;
}

package Seqload::Fasta;
use strict;
use warnings;
use Carp;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw( );

# Constructor. Returns a sequence database object.
sub open {
  my ($class, $filename) = @_;
  open (my $fh, '<', $filename)
    or die "Fatal: Could not open $filename\: $!\n";
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

