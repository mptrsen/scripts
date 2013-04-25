#!/opt/perl/bin/perl
use strict;
use warnings;
use autodie;

use IO::File;
use IO::Dir;
use File::Spec;
use Getopt::Long;

# initialize variables
my $version = 1;
my $fastaf = '';
my %seen = ();
my $help = 0;
my $hitseq = '';
my $verbose = 0;

# get command line options
GetOptions( 
	'v|verbose' => \$verbose,
	'h|help' => \$help,
);

# report and exit if the user wants help
if ($help) {
	print "$0 version $version\n";
	print "Usage: $0 LOGFILE\n"; 
	exit;
}

# ok we have more than one log file, do everything for all of them
foreach my $logf (@ARGV) {

	# find the sequence file from the log
	printf "%-18s %s\n", 'log file:', $logf;
	my $fh = IO::File->new($logf);
	while (<$fh>) {
		if (/Using EST file (.*)$/) {
			$fastaf = $1;
			printf "%-18s %s\n", 'fasta file:', $fastaf;
			last;
		}
	}
	undef $fh;

	# read the sequences into memory
	my $sequence_of = slurp_fasta($fastaf);
	printf "%-18s %d\n", 'sequences:', scalar keys %$sequence_of;

	# check if headers have equal length
	if (&equal_length(keys %$sequence_of)) { 
		print "headers in $fastaf have equal length\n";
		next;
	}
	else { print "headers in $fastaf do not have equal length\n" }

	# check if there may be a substr problem
	if (&no_substr_problem(keys %$sequence_of)) {
		print "headers in $fastaf cannot have substr problems\n";
		next;
	}
	else { print "headers in $fastaf may have substr problems\n" }

	# ok we need to dig deeper
	# go through the log file again
	$fh = IO::File->new($logf);
	while (<$fh>) {
		if ( /processing hit: (.*)_RF\d/ ) {
			$hitseq = $1;
			next if $seen{$hitseq};
			++$seen{$hitseq};
			print "processing hit sequence '$hitseq'... " if $verbose;
		}
		if ( /(.*) and (.*) returned an empty exonerate result/ ) {
			print "$1 was skipped\n";	
		}
	}
	
}

# sub: equal_length
# check whether headers have equal length
# returns 1 if true, 0 if false
sub equal_length {
	my @headers = @_;
	my $len = 0;

	# just get the length of the first header
	$len = sprintf("%d", length $_) and last foreach @headers;

	foreach my $header (@headers) {
		if (length $header != $len) { return 0 }
	}
	return 1;
}

# sub: no_substr_problem
# check whether headers may present substr problems
# returns 1 if true (no problem), 0 if false
sub no_substr_problem {
	my @headers = @_;
	my $count = 0;
	my $n = 0;
	foreach my $header (@headers) {
		foreach my $header2 (@headers) {
			if ( index($header, $header2) > 0 ) {
				$count++;
				if ($count > 1) { return 0 }
			}
		}
		$count = 0;
		$n++;
		print "checked $n headers\n" if $n % 10 == 0;
	}
	return 1;
}

# sub: slurp_fasta
# reads the content of a Fasta file into a hashref
sub slurp_fasta {
	my $fastafile = shift @_;
	my $data = { };
	my $fastafh = Seqload::Fasta->open($fastafile);
	while (my ($h, $s) = $fastafh->next_seq()) {
		$data->{$h} = $s;
	}
	return $data;
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

