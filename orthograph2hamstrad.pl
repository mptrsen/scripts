#!/usr/bin/perl
use strict;
use warnings;
use autodie;

my $usage = <<"__EOT__";
$0 - convert Orthograph results into HaMStRad format.

USAGE:

  $0 INPUTFILE

Writes INPUTFILE in Hamstrad format to stdout. To use on all files in a directory do something like

  for FILE in *.fa; do $0 \$FILE > /path/to/output_aa_dir/\$FILE; done

__EOT__


my $inf = shift @ARGV or print $usage and exit;

my $infh = Seqload::Fasta->open($inf);

while (my ($h, $s) = $infh->next_seq()) {
	my @fields = split(/\|/, $h, 3);
	if ($fields[-1] =~ /\|\.\|/) { # is a reference species
		my @idfields = split(/\|/, $fields[2]);
		# just print the relevant fields along with the sequence
		printf ">%s|%s|%s\n%s\n", 
			$fields[0],   # cog id
			$fields[1],   # reftaxon name
			$idfields[0], # sequence id
			$s,
		;
	}
	else { # is the analyzed species
		# concatenated headers?
		my @concat = split(/&&/, $fields[2]);
		my @partfields = split(/\|/, $concat[0]);
		# print relevant fields, calculate length
		printf ">%s|%s|%s|%s-%d",
			$fields[0],                   # cog id,
			$partfields[-1],              # reftaxon name
			$fields[1],                   # taxon name
			$partfields[0],               # sequence id 
			abs(eval $partfields[1]) + 1, # length
		;
		if (scalar @concat > 1) { # concatenation, add "PPsequence id - length" etc
			for (my $i = 1; $i < scalar @concat; $i++) {
				@partfields = split(/\|/, $concat[$i]);
				printf "PP%s-%d",
					$partfields[0],               # sequence id
					abs(eval $partfields[1]) + 1, # length
				;
			}
		}
		# and the sequence
		printf "\n%s\n", $s;
	}
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
