#!/usr/bin/perl
# read two single-sequence fasta files, generate a dot plot.
# output in plain text, optionally in SVG format.
use strict;
use warnings;
use SVG; # SVG graphics
use Getopt::Long;	# cmd line options

my $svgoutput = 0;
my $dot = '+';

GetOptions( 'svg' => \$svgoutput,
	'dot=s' => \$dot
);

# read in fasta files
my $fileA = shift @ARGV;
my $fileB = shift @ARGV or die "Need two file names as arguments\n";
my ($hdrA, $seqA) = &readFasta($fileA);
my ($hdrB, $seqB) = &readFasta($fileB);

warn "Additional arguments ignored\n" if @ARGV;

# check for differing seq lengths
my $lengthdiff = length($seqA) - length($seqB);
if ($lengthdiff < 0) {
	$seqA .= '-' x abs $lengthdiff; 
}
else {
	$seqB .= '|' x $lengthdiff;
}


# convert strings to arrays
my @seqA = split '', $seqA;
my @seqB = split '', $seqB;

# construct data matrix
my $matrix = [ ];
foreach my $i (0..@seqA-1) {
	foreach my $j (0..@seqB-1) {
		if ($seqA[$j] eq $seqB[$i]) {
			$matrix->[$i]->[$j] = '1';
		}
		else {
			$matrix->[$i]->[$j] = '0';
		}
	}
}

# output
if ($svgoutput) { &printsvg }
else { &printtxt }

#--------------------------------------------------
# # subroutines
#-------------------------------------------------- 
# reads a single-seq fasta file and returns a list of (hdr, seq) 
sub readFasta {
	my $file = shift;
	my ($hdr, $seq) = '';
	open my $fh, '<', $file
		or die "Could not open $file\: $!";
	while (<$fh>) {
		chomp;

		# ignore fasta headers
		if (/^>/) {
			# take only the first seq
			if ($seq) {
				warn "More than one seqs in $file; I will take only the first one\n";
				last;
			}
			else { 
				($hdr = $_) =~ s/>//;
				next;
			}
		}

		$seq .= $_;
	}
	return ($hdr, $seq);
}

# plain text output
sub printtxt {
	# seq A on the x axis
	print '  ';
	print "$_" foreach (@seqA);
	print "\n";
	# y axis
	foreach my $y (0..@seqB-1) {
		print $seqB[$y] . ' ';
		# x axis
		foreach my $x (0..@seqA-1) {
			$matrix->[$y]->[$x] ? print $dot : print ' ';
		}
		print "\n";
	}
}

# SVG output
sub printsvg {
	my $svg = new SVG;
	$svg->title()->cdata("$hdrA vs $hdrB");

	# seq on the x axis
	for (my $x = 0; $x < @seqA; ++$x) {
		$svg->text(
			x => $x+1,
			y => 1,
			style => {
				'font-size' => 1
			})->cdata($seqA[$x]);
	}
	# seq on the y axis
	for (my $y = 0; $y < @seqB; ++$y) {
		$svg->text(
			x => 0,
			y => $y+2,
			style => {
				'font-size' => 1
			})->cdata($seqB[$y]);
	}
	# dot plot
	foreach my $y (0..@seqB-1) {
		foreach my $x (0..@seqA-1) {
			if ($matrix->[$y]->[$x]) { 
				$svg->rectangle(
					x => $x+1,
					y => $y+1.1,
					width => 1,
					height => 1
				);	
			}
		}
	}
	my $xml = $svg->xmlify;	# render SVG into XML
	print $xml;
}
