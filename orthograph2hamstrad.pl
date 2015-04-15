#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use File::Spec::Functions;
use Getopt::Long;
use Data::Dumper;
use Carp;

my $usage = <<"__EOT__";

$0 - convert Orthograph results into HaMStRad format.

USAGE:

  $0 INPUTDIRECTORY OUTPUTDIRECTORY

Writes all files in INPUTDIRECTORY/aa and INPUTDIRECTORY/nt to OUTPUTDIRECTORY/aa and OUTPUTDIRECTORY/nt, respectively. Fasta headers will be corresponding.

__EOT__


my $indir = shift @ARGV or print $usage and exit;
my $outdir = shift @ARGV or print $usage and exit;

# input and output directories
my $aaind = catdir($indir, 'aa');
my $ntind = catdir($indir, 'nt');
my $ntod = catdir($outdir, 'nt');
my $aaod = catdir($outdir, 'aa');

# create nt output dir unless it exists
if (-e $ntod) {
	if (! -d $ntod) {
		die "Fatal: output dir $ntod exists, but is not a directory!\n";
	}
}
else {
	mkdir $ntod;
}

# create aa output dir unless it exists
if (-e $aaod) {
	if (! -d $aaod) {
		die "Fatal: output dir $aaod exists, but is not a directory!\n";
	}
}
else {
	mkdir $aaod;
}

# directory handles
my $aadh;
my $ntdh;
opendir $aadh, $aaind;
opendir $ntdh, $ntind;

while (my $f = readdir($aadh)) {
	# skip everything but aa fasta files
	next unless $f =~ /\.fa$/;
	(my $basen = $f) =~ s/\.aa\.fa$//;
	# the corresponding nt file must exist
	if (!-e catfile($ntind, "$basen.nt.fa")) {
		croak "Fatal: $aaind/$f does not exist in $ntind!\n";
	}
	# read them both in
	my $aadata = fasta2arrayref(catfile($aaind, $basen . '.aa.fa'));
	my $ntdata = fasta2arrayref(catfile($ntind, $basen . '.nt.fa'));
	
	# open output files
	open my $ntofh, '>', catfile($ntod, $basen . '.nt.fa');
	open my $aaofh, '>', catfile($aaod, $basen . '.aa.fa');

	foreach my $item (@$aadata) {
		# get corresponding nt sequence
		my $ntitem = find_sequence_for_taxon($ntdata, $item->{'tax'});
		# print aa headers and aa sequences to aa output file
		printf $aaofh ">%s\n%s\n", magic_hamstr_format($item), $item->{'seq'};
		# print aa headers, but nt sequences to nt output file
		printf $ntofh ">%s\n%s\n", magic_hamstr_format($item), $ntitem->{'seq'};
	}
	close $ntofh;
	close $aaofh;
}
exit;

sub find_sequence_for_taxon {
	my $data = shift;
	my $tax = shift;
	foreach my $item (@$data) {
		if ($item->{'tax'} eq $tax) { return $item }
	}
	# not found
	warn "Warning: could not find nt sequence for $tax in $data->[0]->{'cog'}, leaving it empty\n";
	return { 'seq' => '' };
}

sub fasta2arrayref {
	my $f = shift;
	my $seqs = [ ];
	my $fh = Seqload::Fasta->open($f);
	while (my ($h, $s) = $fh->next_seq()) {
		my @sectors = split /&&/, $h;
		my @first_sector = split /\|/, $sectors[0];
		my $is_reftaxon = $first_sector[-1] eq '.' ? 1 : 0;
		push @$seqs, { 'tax' => $first_sector[1], 'cog' => $first_sector[0], 'hdr' => $h, 'seq' => $s, 'reftaxon' => $is_reftaxon };
	}
	$fh->close();
	return $seqs;
}

sub magic_hamstr_format {
	my $args = shift;
	my $h = $args->{'hdr'};
	my $is_reftaxon = $args->{'reftaxon'};
	my @sectors = split /&&/, $h;
	my @first_sector = split /\|/, $sectors[0];
	my $hamstr_hdr = '';
	if ($is_reftaxon) {
		$hamstr_hdr = join('|', $first_sector[0], $first_sector[1], $first_sector[2]);
	}
	else {
		$hamstr_hdr = sprintf "%s|%s|%s|%s-%d",
			$first_sector[0],                      # cog id
			$first_sector[-1],                     # reftaxon
			$first_sector[1],                      # taxon
			$first_sector[2],                      # seq id
			abs( eval(  $first_sector[3] ) ) + 1,  # length
		;
		if (scalar @sectors > 1) {
			for (my $i = 1; $i < scalar @sectors; ++$i) {
				my @sectorfields = split /\|/, $sectors[$i];
				$hamstr_hdr .= sprintf "PP%s-%d",
					$sectorfields[0],                     # seq id
					abs( eval(  $sectorfields[1] ) ) + 1, # length
				;
			}
		}
	}
	return $hamstr_hdr;
}

sub make_hamstr_format {
	my $s = shift;
	my $new = '';
	# this is a reftaxon
	if ($s->{'hdrs'}->[0]->{'rf'} eq '.') {
		$new = sprintf "%s|%s|%s",
			$s->{'cog'},
			$s->{'tax'},
			$s->{'hdrs'}->[0]->{'id'},
		;
	}
	# is the analyzed species
	else {
		$new = sprintf "%s|%s|%s|%s-%d",
			$s->{'cog'},                                  # cog id
			$s->{'hdrs'}->[0]->{'reftax'},                 # reftaxon name
			$s->{'tax'},                                  # taxon name
			$s->{'hdrs'}->[0]->{'id'},                     # sequence id 
			abs( eval($s->{'hdrs'}->[0]->{'coords'}) + 1 ), # length
		;
		if (scalar @{$s->{'hdrs'}} > 1) { # concatenation, add "PPsequence id - length" etc
			for (my $i = 1; $i < scalar @{$s->{'hdrs'}}; $i++) {
				$new .= sprintf "PP%s-%d",
					$s->{'hdrs'}->[$i]->{'id'},                     # sequence id
					abs( eval($s->{'hdrs'}->[$i]->{'coords'}) + 1 ), # length
			}
		}
	}
	return $new;
}

# read fasta file completely and make fancy data structure
sub slurpfasta {
	my $inf = shift;
	my $seq_of = [ ];
	my $infh = Seqload::Fasta->open($inf);
	while (my ($h, $s) = $infh->next_seq()) {
		my @fields = split /\|/, $h, 3;
		my @hdrs = ( );
		my @concats = split /&&/, $fields[2];
		foreach my $concat (@concats) {
			my @subfields = split /\|/, $concat;
			push @hdrs, {
				'id' => $subfields[0],
				'coords' => $subfields[1],
				'rf' => $subfields[2],
				'reftax' => $subfields[3],
			};
		}
		push @$seq_of, { 
			'hdr'    => $h,
			'cog'    => $fields[0],
			'tax'    => $fields[1],
			'hdrs'   => \@hdrs,
		};
	}
	$infh->close();
	return $seq_of;
}

sub convert_file_to_hamstr_format {
	my $inf = shift;
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

