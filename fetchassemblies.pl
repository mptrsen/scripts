#!/usr/bin/perl
use strict;
use warnings;
use autodie;

use IO::File;
use List::Util qw(first);

scalar @ARGV > 1 or die "Usage: $0 REPORTFILE ASSEMBLYFILE ASSEMBLYFILE ASSEMBLYFILE [...]\n";

my $reportfile = shift @ARGV;

-r $reportfile or die "Error: Not a readable file: '$reportfile'\n";

my @assemblies = @ARGV;

my $fh = IO::File->new($reportfile, 'r');

my $nfh             = undef;
my $assembly        = '';
my $assemblyfile    = undef;
my $assemblycontent = undef;;
my $hdr             = undef;

while (<$fh>) {

	if ( /Assembly: \b([a-zA-Z0-9-]+)\b \[(..)\]/ ) {
		$assembly = $1 . '_' . $2;
		print "Assembly: $assembly\n";
		$assemblyfile = first { /\Q$assembly\E/ } @assemblies;	
		die "Fatal: assembly file for $assembly not in argument list\n" unless $assemblyfile;
		undef $assemblycontent;
		undef $nfh;
		$nfh = IO::File->new($assembly . '.fas', 'w');
		$assemblycontent = slurpfasta($assemblyfile);
	}

	# this part modifies the pseudo-fasta header so that it matches the actual
	# header in the original nucleotide assembly. 
	if ( /^>/ ) {
		s/^>//;
		s/(:| )?\[(revcomp|translate).+$//;
		s/\s*$//;
		if ($$assemblycontent{$_}) {
			print "Sequence '$_'\n";
			printf $nfh ">%s\n%s\n", $_, $$assemblycontent{$_};
		}
		else {
			warn "!! Warning: Sequence '$_' not found\n";
		}
	}

}

# slurp a fasta file
# argument: scalar string filename
# returns: hash reference
sub slurpfasta {
	my $f = shift;
	my $content = {};
	my $fh = Seqload::Fasta->open($f);
	while (my ($h, $s) = $fh->next_seq()) {
		$$content{$h} = $s;
	}
	undef $fh;
	return $content;
}

package Seqload::Fasta;
use Carp;

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
  local $/ = "\n>"; # change the line separator
  return unless defined(my $item = readline($fh));  # read the line(s)
  chomp $item;
  
  if ($. == 1 and $item !~ /^>/) {  # first line is not a header
    croak "Fatal: " . $self->{'filename'} . " is not a FASTA file: Missing descriptor line\n";
  }

  $item =~ s/^>//;

  my ($hdr, $seq) = split(/\n/, $item, 2);
  $seq =~ s/>//g if defined $seq;
  $seq =~ s/\s+//g if defined $seq; # remove all whitespace, including newlines

  return($hdr, $seq);
}

# Destructor. Closes the file and undefs the database object.
sub close {
  my $self = shift;
  my $fh = $self->{'fh'};
  my $filename = $self->{'filename'};
  close($fh) or croak "Fatal: Could not close $filename\: $!\n";
  undef($self);
}

# I dunno if this is required but I guess this is called when you undef() an object
sub DESTROY {
  my $self = shift;
  $self->close;
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
1;

