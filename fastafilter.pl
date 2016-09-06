#!/usr/bin/perl
# documentation before the code
=head1 NAME

fastafilter 

=head1 DESCRIPTION

Reads a header list file and removes corresponding sequences from a fasta file.

=head1 SYNOPSIS

fastafilter.pl [-t] [-v] [-h] -l LISTFILE -f FASTAFILE 

=head1 OPTIONS

=head2 -l LISTFILE 

	File containing the headers to be removed from FASTAFILE (mandatory).
	
=head2 -f FASTAFILE 

	Fasta file to be filtered (mandatory). The filtered file will be named 'FASTAFILE.filtered'.

=head2 -t 

	Create a tracefile containing the sequences that were removed from FASTAFILE. The tracefile will be named 'FASTAFILE.trace'.
	
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

#--------------------------------------------------
# # setup
#-------------------------------------------------- 
use strict;
use warnings;
use File::Spec;
use Getopt::Long;

# variable initialization
my (
	$help,
	$verbose,
	$listfile,
	@fastafiles,
	$outfile,
	$tracefile,
	$delcount,
	$keepcount,
	%duplet
);

GetOptions(
	't'   => \$tracefile,
  'h'   => \$help,
	'v'   => \$verbose
);

$listfile = shift @ARGV or die "You must supply a file with a list of headers and at least one Fasta file!\n";
if (scalar @ARGV > 0) {
	@fastafiles = @ARGV;
}
else { die "You must supply a file with a list of headers and at least one Fasta file!\n" }

# help message etc
if ($help) {
	print <<EOF;
$0 
Options:
-l LISTFILE   file containing the headers to be removed from FASTAFILE (mandatory)
-f FASTAFILE  fasta file to be filtered (mandatory)
-t            create a tracefile with the sequences that were removed from FASTAFILE
-h            prints help message (this one :o))
-v            verbose operation
EOF
exit;
}


#--------------------------------------------------
# # Open all files
#-------------------------------------------------- 
# read in the list file, save in array for speed
my $list = slurp_list($listfile);

foreach my $fastafile (@fastafiles) {
	if ($tracefile) {
		$tracefile = get_tracefile_name($fastafile);
		print "using tracefile\t$tracefile\n";
	}
	my $filteredfile = File::Spec->catfile($fastafile . '.filtered');
	my $tracefile  = File::Spec->catfile($fastafile . '.trace');
	# remove the listed sequences from the fasta file
	my ($remaining_sequences, $removed_sequences) = filter_fasta($fastafile, $list);
	# save the remaining sequences to the filtered fasta file
	write_sequences_to_fasta($filteredfile, $remaining_sequences);
	# save the removed sequences to the trace file
	write_sequences_to_fasta($tracefile,    $removed_sequences);

	#--------------------------------------------------
	# # report
	#-------------------------------------------------- 
	printf "deleted\t%d", scalar @$removed_sequences;
	$tracefile ? printf "\tsaved to %s\n", $tracefile : print "\n";
	printf "kept\t%d\tsaved to %s\n", scalar @$remaining_sequences, $filteredfile;
}


exit;

sub slurp_list {
	my $f = shift @_;
	-e $f or die "Fatal: List file '$f' does not exist!\n";
	open(my $fh, '<', File::Spec->catfile($f)) or die "Fatal: Could not open list file '$listfile': $!\n";
	my $list = [ <$fh> ];
	close $fh;
	chomp @$list;
	foreach my $item (@$list) {
		# remove '>' from entries
		$item =~ s/^>//;
		# remove all trailing whitespace
		$item =~ s/\s*$//;
	}
	return $list;
}

sub get_tracefile_name {
	my $ff = shift @_;
	(my $tf = $ff) =~ s/\.(fa|fas|fasta)$/.$1.trace/i;
	return $tf;
}

sub filter_fasta {
	my $file = shift @_;
	my $list = shift @_;
	my $seqs = slurpfasta($file);
	my $removed = [ ];
	my $remain  = [ ];
	foreach my $s (@$seqs) {
		if (grep { $s->{'hdr'} eq $_ } @$list) {
			push @$removed, $s;
		}
		else {
			push @$remain, $s;
		}
	}
	return ($remain, $removed);
}

sub slurpfasta {
	my $f = shift @_;
	-e $f or die "Fatal: no such file or directory: '$f'\n";
	my $seqs = [ ];
	my $fh = Seqload::Fasta->open($f);
	while (my ($h, $s) = $fh->next_seq()) {
		push @$seqs, { 'hdr' => $h, 'seq' => $s };
	}
	return $seqs;
}

sub write_sequences_to_fasta {
	my $file = shift @_;
	my $seqs = shift @_;
	open my $fh, '>', $file or die "Fatal: Could not open tracefile '$tracefile' $!\n";
	foreach my $seq (@$seqs) {
		printf $fh ">%s\n%s\n", $seq->{'hdr'}, $seq->{'seq'};
	}
	return 1;
}

package Seqload::Fasta;use strict;use warnings;use Carp;require Exporter;our @i=qw(Exporter);
sub open{my($b,$a)=@_;open(my$g,'<',$a)or confess "Could not open $a: $!\n";my$d={fn=>$a,fh=>$g};bless($d,$b);return $d;}
sub next_seq{my$d=shift;my$g=$d->{fh};local$/="\n>";return unless defined(my$c=readline($g));chomp $c;if($.==1 and $c!~/^>/){croak "".$d->{fn}." not a FASTA file: Missing descriptor line\n";}$c=~s/^>//;my($e,$f)=split(/\n/,$c,2);$e=~s/\s+$//;$f=~s/>//g if defined $f;$f=~s/\s+//g if defined $f;return($e,$f);}
sub close{my$d=shift;my$g=$d->{fh};my$a=$d->{filename};close($g)or carp("Could not close $a\: $!\n");undef($d);}
sub DESTROY{my$d=shift;$d->close;}1;
