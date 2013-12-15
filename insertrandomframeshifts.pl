#!/usr/bin/perl
use strict;

if (@ARGV == 0) {
	print <<EOF;
Usage: $0 <i> <fastafile> 
inserts random nucleotides at random positions at percentage rate i.
EOF
exit
}

my $n = $ARGV[0];
my $file = $ARGV[1];
my $header;
my $mod = 0;
my $filenum = 0;

open (my $fh, $file) or die "$!\n";

while (my $line = <$fh>) {
	my $outfile = 'seq_' . sprintf('%05s', $filenum) . '.fa';
	chomp $line;
	if ($line =~ /^>/) {	# is a header
		open (my $outfh, ">$outfile") or die "$!\n";
		print $outfh $line;
		close $outfh;
		next
	}
	# insert random nucleotide at random positions throughout the sequence
	for (my $i = &rnd; $i < length($line); $i=$i+&rnd) {
		if (&rnd > $n) {
			substr($line, $i, 0) = &randomnuc;
			$mod = 1;
		}
	}
	open (my $outfh, ">>$outfile") or die "$!\n";
	$mod ? print $outfh "_withframeshifts\n" : print $outfh "\n";
	print $outfh $line, "\n";
	close($outfh) or die "$!\n";
	$mod = 0;
	$filenum++;
}

close $fh;

# return random nucleotide, equal probabilities
sub randomnuc {
	my $random = rand(10);
	if ($random < 2.5) {
		return 'A';
	}
	elsif ($random >= 2.5 and $random < 5) {
		return 'T';
	}
	elsif ($random >= 5 and $random < 7.5) {
		return 'C';
	}
	else {
		return 'G';
	}
}

# return random integer between 0 and 100
sub rnd {
	return int(rand(100))
}
