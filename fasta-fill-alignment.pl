#!/usr/bin/perl
# Fill an uneven alignment with gaps where sequences are too short.
use strict;
use warnings;

my $maxlen = 0;
my $data = { };

# open fasta file, read data
my $fh = Seqload::Fasta->open(shift @ARGV);
while (my ($h, $s) = $fh->next_seq()) {
	my $len = length $s;
	$maxlen = $len > $maxlen ? $len : $maxlen;
	$$data{$h} = {
		'length' => $len,
		'seq'    => $s
	};
}
undef($fh);

# append gaps to every sequence that is shorter than the maximum length
foreach (keys %$data) {
	my $diff = $maxlen - $$data{$_}{'length'};
	next if $diff == 0; # skip seqs that have maximal length
	$$data{$_}{'seq'} .= '-' x $diff;
}

# output fasta-style
printf ">%s\n%s\n", $_, $$data{$_}{'seq'} foreach (keys %$data);
exit;




package Seqload::Fasta;
use Carp;
# Constructor. Returns a sequence database object.
sub open {
	my ($class,$fn)=@_;
	open(my $fh, '<', $fn)
		or confess "Fatal: Could not open $fn\: $!\n";
	my $self={
		'fn'=>$fn,
		'fh'=>$fh
	};
	bless($self,$class);
	return $self;
}
# Returns the next sequence as an array (hdr, seq). 
sub next_seq {
	my $self=shift;
	my $fh=$self->{'fh'};
	local $/="\n>"; # change the line separator
	return unless defined(my $l=readline($fh));  # read the line(s)
	chomp $l;
	croak "Fatal: ".$self->{'fn'}."is not a FASTA file: Missing header line\n"
		if ($.==1 and $l!~/^>/) ;
	$l=~s/^>//;
	my ($h,$s)=split(/\n/,$l,2);
	if (defined $s) {
		$s=~s/>//g;
		$s=~s/\s+//g # remove all whitespace, including newlines
	}
	return($h,$s);
}
# Destructor. Closes the file and undefs the database object.
sub close {
	my $self=shift;
	my $fh=$self->{'fh'};
	my $fn=$self->{'fn'};
	close($fh) or carp("Warning: Could not close $fn\: $!\n");
	undef($self);
}
1;
