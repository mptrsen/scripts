#!/usr/bin/perl

# Remove all gaps from a fasta file.
# Uses Seqload::Fasta.

use strict;
use warnings;

die "Usage: $0 FASTAFILE\n" unless scalar @ARGV == 1;

my $inf = Seqload::Fasta->open($ARGV[0]);
while (my ($h, $s) = $inf->next_seq()) {
	$s =~ s/-//g;	# remove all gap characters
	printf(">%s\n%s\n", $h, $s);
}


package Seqload::Fasta;

# Documentation before the code
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

=cut

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

