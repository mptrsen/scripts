#!/usr/bin/perl
# documentation before the code
=head1 NAME

fastafilter 

=head1 DESCRIPTION

Reads a header list file and removes corresponding sequences from a fasta file.

=head1 SYNOPSIS

	fastafilter.pl [-t] [-v] [-h] LISTFILE FASTAFILE(S)

=head1 OPTIONS

=head2 LISTFILE 

File containing the headers to be removed from FASTAFILE (mandatory).
	
=head2 FASTAFILE(S)

Fasta file(s) to be filtered (mandatory). Directories are not supported. The filtered file will be named 'FASTAFILE.filtered'.

=head2 -t 

Create a tracefile containing the sequences that were removed from FASTAFILE. The tracefile will be named after the FASTAFILE and have a '.trace.fa' extension.
	
=head2 -h 

Prints help message.

=head1 COPYRIGHT

Copyright (c) 2011 Malte Petersen <mptrsen@uni-bonn.de>

=head1 LICENSE

Licensed under the GNU General Public License.
http://www.gnu.org/copyleft/gpl.html

=cut

use strict;
use warnings;

use Getopt::Long;
use IO::Dir;
use IO::File;
use File::Spec;

my (
	$delete,
	$delcount,
	$help,
	$keepcount,
	$listfile,
	$outfile,
	$tracefile,
	$deleted_seqs,
	@fastafiles,
	$sum_seqs,
	%filtered_files,
);

GetOptions(
	'h' => \$help,
	't' => \$tracefile
);

$listfile = shift @ARGV
	or die "Fatal: You must supply a list file and at least one fasta file!\n";

if (scalar @ARGV < 1) {
	die "Fatal: You must supply a list file and at least one fasta file!\n";
}
else { @fastafiles = @ARGV }

# read the list 
my $fh = IO::File->new($listfile);
my @list = <$fh>;
undef $fh;
# remove empty lines
@list = grep !/^\s*$/, @list;
# remove trailing whitespace
s/\s+$// foreach @list;
# remove leading '>'
s/^>// foreach @list;
# because the list will be empty once we're through everything.
my $num = scalar @list;

# go through all files
foreach my $file (@fastafiles) {
	# reset the trace sequences
	$deleted_seqs = { };
	my $outfh = IO::File->new(File::Spec->catfile($file . '.filtered'), 'w');
	my $fh = Seqload::Fasta->open($file);
	while (my ($h, $s) = $fh->next_seq()) {
		# remove trailing whitespace
		$h =~ s/\s+$//;
		# find in list
		for (my $i = 0; $i < scalar @list; ++$i) {
			if ($list[$i] eq $h) {
				printf "'%s' removed from %s, seq #%d\n", $h, $file, $.;
				# flag for removal
				$delete = 1;
				$sum_seqs++;
				last;
			}
		}
		if ($delete) {
			$deleted_seqs->{$h} = $s;
			$filtered_files{$file}++;
			++$delcount;
			$delete = 0;
		}
		else {
			printf $outfh "%s\n%s\n", $h, $s;
		}
	}
	# write the tracefile if any sequences were deleted
	if ($tracefile and keys %$deleted_seqs) {
		my $tracefn = File::Spec->catfile($file . '.trace.fa');
		hashref2fasta($deleted_seqs, $tracefn);
		print "Wrote them to $tracefn\n";
	}
	$fh->close();
	$outfh->close();
}

# done, report
printf "found %d of %d sequences in %d files:\n",
	$sum_seqs,
	scalar @list,
	scalar @fastafiles;
printf "%d in %s\n", $filtered_files{$_}, $_ foreach keys %filtered_files;

# write the contents of a hashref in fasta format
sub hashref2fasta {
	my $seqs = shift;
	my $fn = shift;
	my $fh = IO::File->new($fn, 'w');
	foreach (keys %$seqs) {
		printf $fh ">%s\n%s\n", $_, $seqs->{$_};
	}
	undef $fh;
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

