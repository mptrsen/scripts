#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use File::Spec::Functions;
use File::Basename;
use Data::Dumper;
use Getopt::Long;

# Reads a consensi.fa.classified file from RepeatModeler,
# fetches the sequences from the RM output directory,
# makes a multiple sequence alignment for each family,
# constructs a HMM for each family for future searching.
#
# Parameters: path to RModeler output directory

my $usage = "Usage: $0 RModeler_dir\n";

my $outdir;
my $opts = GetOptions( "outdir=s" => \$outdir ) or die "Error in command line arguments\n";
$outdir //= '.';

my $rmdir = shift or die $usage;

my $consensi_file = File::Spec->catfile($rmdir, 'consensi.fa.classified');

my $consensus_sequences = Seqload::Fasta::slurp_fasta($consensi_file);

# go through keys, parse round and family information, assign file paths to them
my $props = { };
foreach my $header (keys %$consensus_sequences) {
	$header =~ s/ .+$//; # remove everything after the first part
	my ($rndfam, $name) = split '#', $header;
	my ($rnd, $fam) = split '_', $rndfam;
	$rnd =~ s/^rnd-//; # isolate the number
	$fam =~ s/^family-//; # isolate the number
	printf "header: %s\nround: %s\nfamly: %s\nname: %s\n", $header, $rnd, $fam, $name;
	my $props->{$header} = { 'file' => File::Spec->catfile($rmdir, 'round-' . $rnd, 'family-' . $fam . '.fa'), 'name' => $name };
	printf "File: %s\n", $header, $props->{$header}->{'file'};
	print "Making MSA for $header\n";
	$props->{$header}->{'msa'} = make_alignment($props->{$header});
	print "Making HMM for $header\n";
	$props->{$header}->{'hmm'} = make_hmm($props->{$header});
	print "-------------------\n";
}

sub make_alignment {
	my $inprops = shift @_;
	my $inf = $inprops->{'file'};
	my $outf = catfile($outdir, basename($inf, '.fa') . '.afa');
	system("linsi '$inf' > '$outf' 2> /dev/null") and die;
	return $outf;
}

sub make_hmm {
	my $inprops = shift @_;
	my $inf = $inprops->{'msa'};
	my $name = $inprops->{'name'};
	my $outf = catfile($outdir, basename($inf) . '.hmm');
	system("hmmbuild -n '$name' --informat afa '$outf' '$inf'") and die;
	return $outf;
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
#
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
