#!/usr/bin/perl
use strict;
use warnings;

if (@ARGV == 0) {
	print <<EOF;
Usage: $0 <fastafile> <outdir>
writes each sequence to an individual file in <outdir>
EOF
exit
}

my $file = $ARGV[0];
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

sub insertrandomnuc {
	# insert random nucleotide at random positions throughout the sequence
	my $line = shift;
	for (my $i = &rnd; $i < length($line); $i=$i+&rnd) {
		if (&rnd > 50) {
			substr($line, $i, 0) = &randomnuc;
			$mod = 1;
		}
	return $line;
	}
}
