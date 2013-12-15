#!/usr/bin/perl
# Filter a orthodb file to only contain taxa specified in a input file.
# Arguments: taxa list file, fasta file
# The resulting output file will contain only sequences of taxa in the list.
use strict;
use warnings;
use IO::File;

my $listf = shift(@ARGV);
my $odbf = shift(@ARGV);

my $lfh = IO::File->new($listf);
my @taxa = <$lfh>;
undef($lfh);

chomp @taxa;
@taxa = grep(!/^\s*$/, @taxa);

my $odbfh = Seqload::Fasta->open($odbf);
my $outfh = IO::File->new("$odbf.filter", 'w');
while (my ($h, $s) = $odbfh->next_seq()) {
	chomp($h, $s);
	my @fields = split(/\s+/, $h);
	$fields[0] =~ s/:.*$//;
	die "wah wah wah\n" if length($fields[0]) != 5;
	if (grep(/$fields[0]/, @taxa)) {
		printf($outfh ">%s\n%s\n", $h, $s) or die "Could not write to outfile: $!\n";
	}
}
undef($outfh);
$odbfh->close();
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
		if ($.==1 and $l!~/^>/);
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
