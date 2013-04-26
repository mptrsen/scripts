#!/usr/bin/perl
use strict;
use warnings;
use autodie;

use IO::File;
use IO::Dir;
use List::Util qw(first);
use File::Spec;
use File::Basename;
use File::Temp;
use Getopt::Long;
use Data::Dumper;

my $dir = undef;
my $exonerate = 'exonerate';
my $tcfile = '';
my $taxon = '';
my $geneid = '';
my $genecnt = 0;
my $hitid = '';
my $outputfile = '';
my $verbose = 0;
my $output_sequence_of = {};
my $untranslated_hitid = '';
my $warncnt = 0;
my $ok = 0;
my $okcnt = 0;
my $totalcnt = 0;
my $shf = undef;

GetOptions( 
	'v|verbose'   => \$verbose,
	'exonerate=s' => \$exonerate,
	'shfile=s'    => \$shf,
	'datadir=s'   => \$dir,
);

unless (defined $shf and defined $dir) {
	print "Usage: $0 -shfile SHFILE -datadir DIRECTORY\n";
	exit;
}


# find everything from the sh file
printf "%-18s %s\n", 'sh file:', $shf;
my $fh = IO::File->new($shf);
while (<$fh>) {
	if ( /sequence_file=(.+) -est -taxon=(\w+) / ) {
		printf "%-18s %s\n", 'taxon name:', $2;
		printf "%-18s %s\n", 'original file:', $1;
		$tcfile = File::Spec->catfile($1 . '.mod.tc');
		last;
	}
}
undef $fh;

# some tc files do not exist
if (-e $tcfile) {
	printf "%-18s %s\n", 'translated file:', $tcfile;
}
else {
	die "Fatal: translated file $tcfile not found\n";
}

# get output dir from the tc file name
my $output_dir = get_dir($tcfile);
die "Fatal: output directory not found\n" unless defined $output_dir;
printf "%-18s %s\n", 'output directory:', $output_dir;

# get list of files to process
my $aadir = File::Spec->catdir($output_dir, 'aa');
my $aadirh = IO::Dir->new($aadir);
die "Fatal: could not open dir $aadir\: $!\n" unless defined $aadirh;
my @files = ();
while (my $f = $aadirh->read) {
	next if $f =~ /^\./;
	push @files, File::Spec->catfile($aadir, $f);
}
undef $aadirh;
printf "%-18s %d\n", 'output files:', scalar @files;

# read the sequences into memory
print "Reading translated sequences into memory...\n";
my $sequence_of = slurp_fasta($tcfile);
printf "%-18s %d\n", 'sequences:', scalar keys %$sequence_of;
print "\n";

# check each output file
foreach my $outputfile (@files) {
	printf "output file %s\n", basename $outputfile;
	$output_sequence_of = slurp_fasta($outputfile);
	$ok = 0;

	# remove all other sequences from the hash, we don't care about them
	$output_sequence_of = single($output_sequence_of);
	# fix the identifier (use only the original id) because the RF is not present in the output ids
	$output_sequence_of = { map { get_id($_) => $output_sequence_of->{$_} } keys %$output_sequence_of };

	# was the relevant output sequence concatenated?
	my @concat = grep { /\dPP/ } keys %$output_sequence_of;
	# this is undef if no concatenated header, so no problem with the if
	my $concatenated_header = shift @concat;
	if ( $concatenated_header ) {
		# un-concatenate (split the concatenated stuff up)
		my $concatenated_sequence_of = unconcatenate($concatenated_header);
		$output_sequence_of = { %$output_sequence_of, %$concatenated_sequence_of };
		delete $output_sequence_of->{$concatenated_header};
	}
	print "  output (sub)sequences: ", join " ", keys %$output_sequence_of, "\n";
	foreach my $id (keys %$output_sequence_of) {
		# nominal case
		if (find_sequence($id)) {
			print "    found $id in .tc file\n";
			$ok = 1;
		}
		# problem?
		else {
			print "!!  output sequence with header $id is not (sub)sequence with header $id in .tc file\n";
			$ok = 0;
			print "!!    problems pending. going into deep search mode\n";
			my $real_header = deepsearch($id);
			# identical sequence under different header
			if ($real_header) {
				print "!!      found sequence with header $id as $real_header\n";
			}
			else {
				print "!!      did not find sequence with header $id as (sub)sequence anywhere in .tc file\n";
				print "!!      possible frameshift. running exonerate alignment...\n";
				my $actual_header = get_best_alignment($id);
				if ($actual_header) {
					if ($actual_header eq $id) {
						print "!!      alignment found, sequence is ok: $id -> $actual_header\n";
						$ok = 1;
					}
					else {
						print "!!      alignment found, sequence is not ok: $id -> $actual_header\n";
					}
				}
				else {
					print "!!      no alignment found for $id! something is wrong here!\n";
				}
			}
		}
	}

	# everything ok?
	if ($ok) {
		$okcnt++;
		printf "everything OK for %s\n", basename($outputfile);
	}
	print "\n";
	$genecnt++;
}

printf "checked %d genes\n%d ok\n%d warnings\n", $genecnt,  $okcnt, $genecnt - $okcnt;

exit;

# get the output dir that belongs to this file
# call: get_dir($filename)
# returns: scalar string filename
sub get_dir {
	my $tcfile = shift @_;
	my @dirs = ();
	# everything after and including the first dot will be removed to form the dirname
	(my $dirname = $tcfile) =~ s/\..*//;
	my $dirh = IO::Dir->new($dir);
	if (defined $dirh) {
		while (defined($_ = $dirh->read)) {
			# skip everything that starts with a dot or isn't a dir
			next if /^\./;
			next unless -d;
			if ( /^$dirname/ ) {
				return $_;
			}
		}
	}
	return undef;
}

# get the actual id from a hamstr output header
# i.e. the last part of the header
sub get_id {
	my $longid = shift @_;
	(my $shortid = $longid) =~ s/.*\|([a-zA-Z0-9._-]+)/$1/;
	$shortid =~ s/-\d+$//;
	return $shortid;
}

# sub: slurp_fasta
# reads the content of a Fasta file into a hashref
sub slurp_fasta {
	my $tcfile = shift @_;
	my $data = { };
	my $tcfileh = Seqload::Fasta->open($tcfile);
	die "Fatal: could not open $tcfile\n" unless defined $tcfileh;
	while (my ($h, $s) = $tcfileh->next_seq()) {
		$data->{$h} = $s;
	}
	return $data;
}

# find a sequence in all possible reading frames
sub find_sequence {
	my $header = shift @_;
	my $actual_hdr = '';
	for my $i (1..6) {
		$actual_hdr = $header . "_RF$i.0";
		print "checking for $header in $actual_hdr\n" if $verbose;;
		# check if sequence is subsequence?
		if ( $sequence_of->{$actual_hdr} =~ /$output_sequence_of->{$header}/ ) {
			print "found $header in $actual_hdr\n" if $verbose;;
			return $actual_hdr;
		}
	}
	return undef;
}

# test against all sequences
sub deepsearch {
	my $header = shift @_;
	while (my ($real_header, $real_sequence) = each %$sequence_of) {
		#printf "comparing %s:\n%s\nand %s:\n%s\n", $header, $output_sequence_of->{$header}, $real_header, $sequence_of->{$real_header};
		if ( $real_sequence =~ /$output_sequence_of->{$header}/ ) {
			return $real_header;
		}
		#print "no luck!\n\n";
	}
	return undef;
}

# undo concatenation
# call: unconcatenate($header)
# returns: hashref
sub unconcatenate {
	my $concatenated_header = shift @_;
	# split this concatenated sequence into its parts
	my $substr_start = 0;
	my $substr_len = 0;
	my $concatenated_sequence_of = {};
	while ( $concatenated_header =~ m/([a-zA-Z0-9_]+)-(\d+)PP/gc ) {
		if (defined $2) { $substr_len = $2 }
		else { $substr_len = -0 }
		$concatenated_sequence_of->{$1} = substr $output_sequence_of->{$concatenated_header}, $substr_start, $substr_len;
		$substr_start += $2;
	}
	# add the last sequence
	# \G matches where last m//g left off
	if ( $concatenated_header =~ m/\G(.*)$/g ) {
		$substr_len = 999999;
		$concatenated_sequence_of->{$1} = substr $output_sequence_of->{$concatenated_header}, $substr_start, $substr_len;
	}
	if ($verbose) {
		print "concatenated subseqs:\n";
		printf ">%s\n%s\n", $_, $concatenated_sequence_of->{$_} foreach keys %$concatenated_sequence_of;
		print "complete sequence:\n";
		print $output_sequence_of->{$concatenated_header}, "\n";
	}
	return $concatenated_sequence_of;
}

# single out the relevant sequence
# returns: hashref
sub single {
	my $data = shift @_;
	my @relevant_keys = grep { /.*\|.*\|.*\|./ } keys %$data;
	my $relevant_key = shift @relevant_keys;
	$data = { $relevant_key => $data->{$relevant_key} };
	return $data;
}

# get the best alignment for a sequence
# arguments: scalar string (sequence id)
# returns: scalar string (sequence id of best match)
sub get_best_alignment {
	my $query = shift @_;
	my $ryo = '%s %ti\n';
	my $tmpfh = File::Temp->new( 'UNLINK' => 1 );
	printf $tmpfh ">$query\n$output_sequence_of->{$query}\n";
	close $tmpfh;
	my @exoneratecmd = qq( $exonerate --ryo "$ryo" --verbose 0 --showalignment no --showvulgar no --query $tmpfh --target $tcfile 2> /dev/null );
	my $result = [ `@exoneratecmd` ];

	# no result
	unless (@$result) { return undef }

	# result
	my $hit_with_score = {};
	foreach (@$result) {
		chomp;
		my ($score, $hit) = split;
		$hit_with_score->{$score} = $hit;
	}

	# sort by score, return the best one
	my @sorted_scores = sort { $b <=> $a } keys %$hit_with_score;
	my $bestscore = shift @sorted_scores;
	$hit_with_score->{$bestscore} =~ s/_RF\d\.\d$//;
	return $hit_with_score->{$bestscore};
}


####################
# 
# Seqload::Fasta package
# for simple and error-free loading of fasta sequence data
# 
####################

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

