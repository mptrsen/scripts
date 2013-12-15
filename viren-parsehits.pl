#!/usr/bin/perl
use strict;
use warnings;

use File::Basename;
use File::Spec;
use IO::File;
use IO::Dir;
use Data::Dumper;

my $data = {};

my $fh = IO::File->new(shift(@ARGV));
my $assdir = shift(@ARGV) or die "wah\n";

my $a;

while (<$fh>) {
	next if /^# [^A]/;
	if (/^# Assembly: (\w+-\d+)/) {
		$a = $1;
		unless(ref($$data{$a})) { $$data{$a} = [] };
	}
	else {
		my @c = split;
		push(@{$$data{$a}}, $c[0]) ;
	}
}

foreach my $ass (keys(%$data)) {

	# find the matching file
	my $file = &findfile($ass);

	# slurp the file into memory
	my $sequences = &slurpfasta($file);

	# print the hit sequences
	print Dumper($$data{$ass}); exit;
	foreach my $s (@$data{$ass}) {
		print $$sequences{$s}, "\n";
	}
	
	# free mem
	undef($sequences);
}

# find a file that contains a string in its name
# argument: scalar string
sub findfile {
	my $fn = shift;
	my $dirh = IO::Dir->new($assdir);
	while (my $f = $dirh->read()) {
		# skip dotfiles
		next if $f =~ /^\./;
		if ($f =~ /$fn/) { 
			undef($dirh);
			return $f;
		}
	}
	return 0;
}

# slurp a fasta file
# argument: scalar string filename
# returns: hash reference
sub slurpfasta {
	my $f = shift;
	my $content = {};
	my $fh = Seqload::Fasta->open(File::Spec->catfile($assdir, $f));
	while (my ($h, $s) = $fh->next_seq()) {
		$$content{$h} = $s;
	}
	$fh->close();
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
    croak "Fatal: " . $self->{'filename'} . "is not a FASTA file: Missing descriptor line\n";
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
