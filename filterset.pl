#!/usr/bin/perl
use strict;
use warnings;
use autodie;

use Data::Dumper;

my $setfile = shift;
my $apisufile1 = shift;
my $phumafile1 = shift;
my $apisufile2 = shift;
my $phumafile2 = shift;

my $set = slurp_fasta_arrayref($setfile);

my $apisuseqs_nt = Seqload::Fasta::slurp_fasta($apisufile1);
my $phumaseqs_nt = Seqload::Fasta::slurp_fasta($phumafile1);
my $apisuseqs_aa = Seqload::Fasta::slurp_fasta($apisufile2);
my $phumaseqs_aa = Seqload::Fasta::slurp_fasta($phumafile2);


my $eogid = '';
my $eogcnt = 0;
open my $aaoutfh, '>', '/dev/null';
open my $ntoutfh, '>', '/dev/null';

while (my ($h, $s) = splice(@$set, 0, 2)) {
	next unless ($h =~ /PHUMA/ or $h =~ /APISU/);
	print "hdr: $h\n";
	my @fields = split ' ', $h;

	my $new_eogid = $fields[2];
	print "old EOG id: $eogid\n";

 	if ($new_eogid ne $eogid) {
		$eogcnt++;
 		$eogid = $new_eogid;
		print "new EOG id: $new_eogid\n";

		close $aaoutfh;
		close $ntoutfh;
		open $ntoutfh, '>', $fields[2] . '.nt.fa';
		open $aaoutfh, '>', $fields[2] . '.aa.fa';
	}

	$fields[3] =~ s/-P.$//;
	print $fields[3], "\n";

	if (grep { $_ =~ /$fields[3]/ } keys %$apisuseqs_nt) {
		print "apisu: $fields[3]\n";
		printf $ntoutfh ">%s\n%s\n", $fields[3], $apisuseqs_nt->{$fields[3]} ;
		printf $aaoutfh ">%s\n%s\n", $fields[3], $apisuseqs_aa->{$fields[3]};
	}
	elsif (grep { $_ =~ /$fields[3]/ } keys %$phumaseqs_nt) {
		print "phuma: $fields[3]\n";
		printf $ntoutfh ">%s\n%s\n", $fields[3], $phumaseqs_nt->{$fields[3]} ;
		printf $aaoutfh ">%s\n%s\n", $fields[3], $phumaseqs_aa->{$fields[3]} ;
	}
	
}

print "done, got $eogcnt genes\n";

sub slurp_fasta_arrayref {
	my $f = shift;
	my $s = [ ];
	my $fh = Seqload::Fasta->open($f);
	while (my @p = $fh->next_seq()) {
		push @$s, @p;
	}
	return $s;
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
  CORE::open (my $fh, '<', $filename)
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

