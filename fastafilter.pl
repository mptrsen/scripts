#!/usr/bin/perl
# documentation before the code
=head1 NAME#{{{

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

=cut#}}}

#--------------------------------------------------
# # setup
#-------------------------------------------------- 
use strict;#{{{
use warnings;
use File::Spec;
use Getopt::Long;

# variable initialization
my (
	$help,
	$verbose,
	$listfile,
	$fastafile,
	$outfile,
	$tracefile,
	$delcount,
	$keepcount,
	%duplet
);

GetOptions(
  'l=s' => \$listfile,
	'f=s' => \$fastafile,
	't'   => \$tracefile,
  'h'   => \$help,
	'v'   => \$verbose
);#}}}

# help message etc
if ($help) {#{{{
	print <<EOF;#{{{
$0 
Options:
-l LISTFILE   file containing the headers to be removed from FASTAFILE (mandatory)
-f FASTAFILE  fasta file to be filtered (mandatory)
-t            create a tracefile with the sequences that were removed from FASTAFILE
-h            prints help message (this one :o))
-v            verbose operation
EOF
exit;
}#}}}

die "Fatal: Mandatory argument -l missing\n" 
	unless $listfile;

die "Fatal: Mandatory argument -f missing\n"
	unless $fastafile;#}}}

#--------------------------------------------------
# # Open all files
#-------------------------------------------------- 
# read in the list file, save in array for speed#{{{
open(my $fh, '<', File::Spec->catfile($listfile))
	or die "Fatal: Could not open list file $listfile: $!\n";
my @list = <$fh>;
close $fh;
chomp @list;
# make sure the list contains only headers
@list = grep( /^>/, @list);
# remove all trailing whitespace from the headers
s/\s+$// foreach @list;

# open the tracefile if specified
if ($tracefile) {
	($tracefile = $fastafile) =~ s/\.(fa|fas|fasta)$/.$1.trace/i;
	print "using tracefile\t$tracefile\n";
	open (my $tracefh, '>', File::Spec->catfile($tracefile))
		or die "Fatal: Could not open tracefile $tracefile $!\n";
	close $tracefh;
}

# open the output file
($outfile = $fastafile) =~ s/\.(fa|fas|fasta)$/.$1.filtered/i;
print "using outfile\t$outfile\n";
open(my $outfh, '>', File::Spec->catfile($outfile))
	or die "Fatal: Could not open output file $outfile $!\n";

# open the fasta file
open($fh, '<', File::Spec->catfile($fastafile))
	or die "Fatal: Could not open fasta file $fastafile $!\n";#}}}

#--------------------------------------------------
# # loop through the fasta file
#-------------------------------------------------- 
my $delete = 0;#{{{
while (my $line = <$fh>) {
	chomp $line;
	# remove trailing whitespace
	$line =~ s/\s+$//;
	if ($line =~ /^>/) {
		# for all headers but the first 
		if (defined $duplet{'seq'}) {
			# find the header in the list, flag for deletion
			for (my $i = 0; $i < scalar @list; ++$i) {
				if ($duplet {'hdr'} =~ /^$list[$i]/) { 				#KM: original: # if ($duplet{'hdr'} eq $list[$i]) { ### KM	if ($duplet{'hdr'} eq $list[$i]) {### kann man hier nicht irgendwie die Gene rausziehen???
					print "$duplet{'hdr'} == $list[$i]\n" if $verbose;
					$delete = 1;
					# remove from list, makes future searches faster 	#KM: auskommentiert damit das durchlaeuft bis es nix mehr findet!
					# splice(@list, $i, 1);						#KM: auskommentiert
					 last; 									#KM: was bedeuted das??
				} 
				else { $delete = 0 }
			}
			# either save or discard the seq
			&distribute_seq(\%duplet);
		}
		$duplet{'hdr'} = $line;
		$duplet{'seq'} = '';
	}
	# collect sequences
	else { $duplet{'seq'} .= $line }
}
# once more for the last seq
&distribute_seq(\%duplet);#}}}

#--------------------------------------------------
# # close all files
#-------------------------------------------------- 
close $fh; #{{{
close $outfh;
if ($tracefile) {
	close $tracefile;
}#}}}

#--------------------------------------------------
# # report
#-------------------------------------------------- 
printf "deleted\t%d", $delcount;#{{{
$tracefile ? printf "\tsaved to %s\n", $tracefile : print "\n";
printf "kept\t%d\tsaved to %s\n", $keepcount, $outfile;

print "not found in $fastafile:\n";
print $_ . "\n" foreach @list;#}}}

# sub: distribute_seq
# saves a sequence either to outfile or tracefile. if tracefile is not used, the sequence is discarded.
sub distribute_seq {#{{{
	my $duplet = shift;
	if ($delete) {
		if (defined $tracefile) {
			open (my $tracefh, '>>', $tracefile)
				or die "Fatal: Could not open tracefile $tracefile $!\n";
			print $tracefh $duplet{'hdr'} . "\n" . $duplet{'seq'} . "\n";
			print "saved $duplet{'hdr'} to $tracefile\n" if $verbose;
			close $tracefh;
		}
		++$delcount;
	}
	# save only those that do not occur in the list
	else {
		print $outfh $duplet{'hdr'} . "\n" . $duplet{'seq'} . "\n";
		print "saved $duplet{'hdr'} to $outfile\n" if $verbose;
		++$keepcount;
	}
	$delete = 0;
}#}}}
