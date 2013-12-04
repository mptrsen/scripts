#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use File::Temp;
use File::Basename;
use File::Spec;
use Getopt::Long;

my $skipfirst = 0;

GetOptions(
	'skipfirst' => \$skipfirst,
);

my $usage = "Usage: $0 OGSFILE TRANSCRIPTOMEFILE\n";

scalar @ARGV == 2 or die $usage;


my $ogs = Seqload::Fasta::slurp_fasta($ARGV[0]);

my $transcripts = Seqload::Fasta::slurp_fasta($ARGV[1]);

unless (scalar keys %$ogs == scalar keys %$transcripts) {
	print "Unequal number of sequences!\n";
}

my %seen = ();
my $nupd = 0;
my $n = 0;

my $new_ogs_file = File::Spec->catfile('/tmp', 'corresp-' . basename($ARGV[0]));
my $new_transcripts_file = File::Spec->catfile('/tmp', 'corresp-' . basename($ARGV[1]));
open my $new_ogs, '>', $new_ogs_file;
open my $new_transcripts, '>', $new_transcripts_file;

foreach my $hdr (sort {$a cmp $b} keys %$ogs) {
	unless (exists $transcripts->{$hdr}) {
		if ($skipfirst) {
			print "Not found in transcriptome: $hdr, skipping\n";
			$skipfirst = 0;
			next;
		} else {
			die "Not found in transcriptome: $hdr\n";
		}
	}
	
	die "Non-unique header: $hdr\n" if $seen{$hdr}++;
	
	# print to files 
	my $aafn = fastaify($hdr, $ogs->{$hdr});
	my $ntfn = fastaify($hdr, $transcripts->{$hdr});

	# some settings
	my $outfile         = '/tmp/exonerate.out';
	my $score_threshold = 30;
	my $exonerate_model = 'protein2genome';
	my $exonerate_ryo   = '>ca\n%tcs>qa\n%qas';

	#printf ">%s\n%s\n>%s\n%s\n", $hdr . ' (query)', $ogs->{$hdr}, $hdr . ' (target)', $transcripts->{$hdr};

	local $| = 0;
	print "Checking $hdr... ";
	
	# run exonerate
	my @command = qq( exonerate --bestn 1 --score $score_threshold --ryo '$exonerate_ryo' --model $exonerate_model --querytype protein --targettype dna --verbose 0 --showalignment no --showvulgar no $aafn $ntfn > $outfile );

	system(@command) and die $?;

	# write new sequences to file
	my $res = Seqload::Fasta::slurp_fasta($outfile);
	if (!$res->{'ca'}) {
		print "no alignment found!\n";
		next;
	}
	elsif ($res->{'ca'} ne $transcripts->{$hdr}) {
		printf $new_ogs ">%s\n%s\n", $hdr, $res->{'qa'};
		printf $new_transcripts ">%s\n%s\n", $hdr, $res->{'ca'};
		++$nupd;
		print "done, updated\n";
		
	}
	else {
		print "done, unchanged\n";
	}
	++$n;
}

print "Done, updated $nupd of $n sequences, written to $new_ogs_file and $new_transcripts_file\n";

exit;

sub fastaify {
	my $fh = File::Temp->new();
	printf $fh ">%s\n%s\n", $_[0], $_[1];
	close $fh;
	return $fh;
}

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
		# remove possible taxon shorthand
		$h =~ s/^[A-Z]{5} //;
		# we only need the id field
		my @fields = split /\s+/, $h;
		# remove possible -RA/-PA suffixes
		$fields[0] =~ s/-\w\w//;
		# ok you got it
		$sequences->{$fields[0]} = $s;
	}
	undef $infh;
	return $sequences;
}

