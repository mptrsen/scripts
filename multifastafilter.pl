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

	Create a tracefile containing the sequences that were removed from FASTAFILE. The tracefile will be named after the LISTFILE and have a '.trace.fa' extension.
	
=head2 -h 

	Prints help message.

=head2 -v

	Verbose operation: prints more information. In essence, for every sequence in FASTAFILE.

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
	%traceseqs,
	$verbose,
	@fastafiles,
);

GetOptions(
	'h' => \$help,
	'v' => \$verbose,
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
	my $outfh = IO::File->new(File::Spec->catfile($file . '.filtered'), 'w');
	my $fh = Seqload::Fasta->open($file);
	while (my ($h, $s) = $fh->next_seq()) {
		# remove trailing whitespace
		$h =~ s/\s+$//;
		# find in list
		for (my $i = 0; $i < scalar @list; ++$i) {
			if ($list[$i] eq $h) {
				printf "'%s' (%s) removed from %s, seq #%d\n", $list[$i], $h, $file, $.;
				# flag for removal
				$delete = 1;
				last;
			}
		}
		if ($delete) {
			$traceseqs{$h} = $s;
			++$delcount;
			$delete = 0;
		}
		else {
			printf $outfh "%s\n%s\n", $h, $s;
		}
	}
	$fh->close();
	$outfh->close();
}

# done, report
printf "found %d of %d sequences in %d files:\n",
	scalar keys %traceseqs,
	scalar @list,
	scalar @fastafiles;
printf "%s\n", $_ foreach keys %traceseqs;

# write the tracefile
if ($tracefile) {
	my $tracefn = File::Spec->catfile($listfile . '.trace.fa');
	my $tracefh = IO::File->new($tracefn, 'w');
	foreach (keys %traceseqs) {
		printf $tracefh ">%s\n%s\n", $_, $traceseqs{$_};
	}
	undef $tracefh;
	print "Wrote them to $tracefn\n";
	$tracefh->close();
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

