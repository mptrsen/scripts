#!/usr/bin/perl
use strict;
use warnings;
use autodie;

use Getopt::Long;

# Removes sequences that do not match the filter pattern, similar to grep.
# Filter pattern can be provided as command line argument or as a list of
# patterns in a file. Matching can also be inverted.

my $f = undef; # file with patterns
my $v = undef; # invert pattern
my $F = undef; # fixed strings
my $h = undef; # help

my $usage = "Usage: $0 [options] [pattern] fastafile\n";

my $help = "$usage\n";
$help .= "Options:\n";
$help .= "    -h          print this help\n";
$help .= "    -f file     read (addional) patterns from file\n";
$help .= "    -F          interpret patterns as fixed strings instead of regular expressions\n";
$help .= "    -v          invert match, to select non-matching sequences\n";

# make sure to heed case for options
Getopt::Long::Configure( qw(no_ignore_case) );

GetOptions(
	'f|file=s'        => \$f,
	'v|invert-match'  => \$v,
	'F|fixed-strings' => \$F,
	'h|help'          => \$h,
) or die $usage;

if ($h) { print $help and exit }

my $infile = pop @ARGV or die $usage;

my @patterns = @ARGV;

# add filter patterns from file to pattern list
if ($f) {
	open my $fh, '<', $f;
	while (<$fh>) {
		chomp;
		push @patterns, $_;
	}
	close $fh;
}

die "Error: no search patterns" unless scalar @patterns;

my $fh = Seqload::Fasta->open($infile);

# flag to hold print state
my $print = 0;

while (my ($h, $s) = $fh->next_seq()) {
	# normal operation, print only those that match pattern, so start with $print = 0
	# inverted operation, print only those that _do not match_ pattern, so start with $print = 1
	$print = $v ? 1 : 0;
	# fixed string, must be a substring
	if ($F) {
		if (grep { index($h, $_) != -1 } @patterns) { $print = ! $print }
	}
	# not fixed string, just need to match somewhere
	else {
		if (grep { $h =~ /$_/ } @patterns) { $print = ! $print }
	}
	# if matched, print and start over
	if ($print) {  printf ">%s\n%s\n", $h, $s  };
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
