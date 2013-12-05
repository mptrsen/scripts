#!/usr/bin/env perl
use strict;
use warnings;
use autodie;
use Getopt::Long;
use Data::Dumper;
use utf8;

my %opts;

GetOptions( \%opts,
	'sequence-file|s=s',
	'thesaurus|t=s',
	'distfile|d=s',
	'identity-threshold=i'
) or die "Unknown option";

my $seqf               = $opts{'sequence-file'};
my $thesf              = $opts{'thesaurus'};
my $distf              = $opts{'distfile'};
my $identity_threshold = $opts{'identity-threshold'};

my $usage = "Usage: $0 -sequence-file FASTAFILE -thesaurus THESAURUSFILE -distfile DISTFILE\n";

$seqf //= die $usage;
$thesf //= die $usage;
$distf //= die $usage;
$identity_threshold //= 95;

my $haplotype_label_format = '%.3s_%.3s_%.3s';

my $sequences = Seqload::Fasta::slurp_fasta($seqf);

foreach my $h (keys %$sequences) {
	$sequences->{$h} =~ s/[^ATCG]/N/g;
}

my $thesaurus = slurp_thesaurus($thesf);

$sequences = correct_drainage($sequences, $thesaurus);

my $drainages = get_unique_drainages($sequences);

my ($haplotypes, $n_haplotypes) = haplotypify($sequences);

print_haplotypes($haplotypes);
print "$n_haplotypes haplotypes\n";

exit;
my $m = make_matrix($haplotypes, $drainages);

print_matrix($m);

sub print_matrix {
	my $m = shift;
	open my $ofh, '>', 'table.txt';
	for my $x (0 .. $#$m) {
		for (my $y = 0; $y < scalar @{$m->[$x]}; $y++) {
			print $ofh $m->[$x]->[$y], "\t";
		}
		print $ofh "\n";
	}
	close $ofh;
}

sub make_matrix {
	my $haplotypes = shift;
	my $drainages  = shift;
	my $m = [ ];
	my $i = 0;
	foreach my $drain (@$drainages) {
		$m->[0]->[$i++] = $drain;
	}
	print Dumper $m; exit;
	while (my ($species, $data) = each %$haplotypes) {
		foreach my $set (@$data) {
			print Dumper $set; exit;
		}
	}
}

sub make_matrix2 {
	my $ht = shift;
	my $drainages = shift;
	my $m  = [ ];
	my $i = 0;
	my $j = 1;
	foreach my $name (keys %$ht) { 
		my ($gen, $spec) = split '_', $name, 2;
		foreach my $haplotype (@{$ht->{$name}}) {
			$m->[0]->[$i++] = sprintf $haplotype_label_format, $gen, $spec, $haplotype->{'drain'};
		}
	}
	foreach my $drain (@$drainages) {
		$m->[$j++]->[0] = $drain;
	}
	for (my $y = 1; $y < scalar @$m; $y++) {
		for (my $x = 1; $x < scalar @$drainages; $x++) {
			$m->[$x]->[$y] = 0;
		}
	}
	return $m;
}

sub print_new_fasta {
	my $ht = shift;
	foreach my $spec (sort keys %$ht) {
		foreach my $h (@{$ht->{$spec}}) {
			my $header = sprintf "%s|%s|%s", $spec, $h->{'drain'}, $h->{'country'};
			printf ">%s\n%s\n", $header, $h->{'seq'};
		}
	}
}

sub print_haplotypes {
	my $ht = shift;
	print "Haplotype table:\n-------------------------------------------------\n";
	foreach my $spec (sort keys %$ht) {
		foreach my $set (sort {$a->{'drain'} cmp $b->{'drain'}} @{$ht->{$spec}}) {
			printf "%-25s %-10s %s\n", 
				$spec,
				$set->{'drain'}, 
				$set->{'country'}
			;
		}
	}
}

sub haplotypify {
	my $seqs = shift;
	my $d = {};
	my $add = 0;
	my $n_ht;
	while (my ($h, $s) = each %$seqs) {
		my @fields = split /_/, $h;
		my $spec = $fields[0] . '_' . $fields[1];
		if (exists $d->{$spec}) {
			print "species identical: $spec\n";
			# skip this if drainage and sequence are identical
			if (grep { $fields[2] eq $_->{'drain'} } @{$d->{$spec}})  {
				print "drain identical: $fields[2]\n";
				print "testing $h against other seqs of this species...\n";
				my $avg_diff = compare_seqs($s, $d->{$spec});
				printf "avg diff: %f (%.2f%%)\n", $avg_diff, $avg_diff * 100;
				if (1 - $avg_diff * 100 >= $identity_threshold / 100) {
					print '1 - $avg_diff * 100 >= $identity_threshold / 100', "\n";
					printf "seq more than %.2f%% identical, not a new haplotype, skipping\n", $identity_threshold ;
				}
				# oops, the sequence is different -> new haplotype?
				else {
					print "!! SEQ DIFFERENT !!\n";
					$add = 1;
				}
			}
			# new drain -> new haplotype
			else {
				print "new drain: $fields[2]\n";
				$add = 1;
			}
		}
		# new species -> new haplotype
		else {
			print ">>NEW HAPLOTYPE: $spec $fields[2] $fields[3]\n";
			$add = 1;
		}
		if ($add) {
			push @{$d->{$spec}}, {
				'drain'   => $fields[2],
				'country' => $fields[3],
				'plate'   => $fields[4],
				'well'    => $fields[5],
				'seq'     => $s,
			};
			++$n_ht;
			$add = 0;
			printf ">>Added new haplotype: %s, %s, %s\n", $spec, $fields[2], $fields[3];
		}
	}
	return ($d, $n_ht);
}

sub compare_seqs {
	my $newseq   = shift;
	my $prevseqs = shift;
	my $sum_diffs = 0;
	my $c = 0;
	foreach my $prevs (@$prevseqs) {
		my $dist = k2pdiff($newseq, $prevs->{'seq'});
		print $dist, "\n";
		$sum_diffs += $dist;
		++$c;
	}
	# return average difference
	return $sum_diffs/$c;
}

sub k2pdiff {
	my $seqA = shift;
	my $seqB = shift;
	die "Unequal sequence lengths in k2p comparison\n" if length($seqA) != length($seqB);
	my $s_equal    = 0;
	my $s_transit  = 0;
	my $s_transv   = 0;
	my $s_ambig    = 0;
	for (my $i = 0; $i < length $seqA; $i++) {
		my $nucA = substr $seqA, $i, 1;
		my $nucB = substr $seqB, $i, 1;
		# equal sites
		if ($nucA eq $nucB) {
			++$s_equal;
		}
		# transition (A <-> G)
		elsif (transition($nucA, $nucB)) { 
			++$s_transit;
		}
		# transversion (T <-> C)
		elsif (transversion($nucA, $nucB)) { 
			++$s_transv;
		}
		# ambiguous site (N or -)
		elsif ($nucA =~ /[nN-]/ or $nucB =~ /[nN-]/) {
			$s_ambig++;
		}
	}
	# transition frequency
	my $p = $s_transit / length $seqA;
	# transversion frequency
	my $q = $s_transv  / length $seqA;
	# kimura two-parameter distance
	return -0.5 * log(1 - 2 * $p - $q) - 0.25 * log(1 - 2 * $q);
}

sub transversion {
	my $n1 = shift;
	my $n2 = shift;
	if (lc $n1 eq 'c' and lc $n2 eq 't') { return 1 }
	elsif (lc $n1 eq 't' and lc $n2 eq 'c') { return 1}
	else { return 0 }
}

sub transition {
	my $n1 = shift;
	my $n2 = shift;
	if (lc $n1 eq 'a' and lc $n2 eq 'g') { return 1 }
	elsif (lc $n1 eq 'g' and lc $n2 eq 'a') { return 1}
	else { return 0 }
}

sub diff {
	my $seqA = shift;
	my $seqB = shift;
	my $s_equal = 0;
	my $s_diff  = 0;
	my $s_ambig = 0;
	for (my $i = 0; $i < length $seqA; $i++) {
		my $nucA = substr $seqA, $i, 1;
		my $nucB = substr $seqB, $i, 1;
		if ($nucA eq $nucB) {
			$s_equal++;
		}
		elsif ($nucA =~ /[nN-]/ or $nucB =~ /[nN-]/) {
			$s_ambig++;
		}
		else {
			$s_diff++;
		}
	}
	printf "eq: %d\nambig: %d\ndiff: %d\nperc eq: %.2f\n", $s_equal, $s_ambig, $s_diff, $s_equal/length $seqA;
	return sprintf("%.2f", $s_equal/length($seqA));
}

sub get_unique_drainages {
	my $seqs = shift;
	my %seen = ();
	my @uniq = ();
	while (my $h = each %$seqs) {
		my @fields = split /_/, $h, 7;
		next if $seen{$fields[2]}++;
		push @uniq, $fields[2];
	}
	return \@uniq;
}

sub correct_drainage {
	my $seqs = shift;
	my $thes = shift;
	while (my ($h, $s) = each %$seqs) {
		delete $seqs->{$h};
		my @fields = split /_/, $h, 7;
		$fields[2] =~ $thes->{$fields[2]};
		$seqs->{join "_", @fields} = $s;
	}
	return $seqs;
}

sub slurp_thesaurus {
	my $f = shift;
	my $t = {};
	open my $fh, '<', $f or die $!;
	while (<$fh>) {
		next if /^#/;
		next if /^\s+$/;
		s/^\s+//;
		s/\s+$//;
		my @fields = split /\s+=\s+/;
		$t->{$fields[0]} = $fields[1];
	}
	return $t;
}

# Documentation before the code#{{{#{{{
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

=cut#}}}

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
}#}}}
