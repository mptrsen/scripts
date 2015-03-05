#!/opt/perl/bin/perl
use strict;
use warnings;
use autodie;

my $fn = shift @ARGV;
my %c = ( );
my %bp = ( );
my $n = 0;

open my $fh, '<', $fn;
while (my $line = <$fh>) {
	# sum up the total bp
	if ($line =~ /number of .* (\d+)/) { $n += $1 }
	if ($line =~ m/
		nucleotide
		\s+
		\d+\s+:\s+\d+		# start : end
		\s+\|\s+
		\d+\sbp					# length 
		\s+\|\s+
		(\d+)\sBP				# normalized length, without indels
		\s+\|\s+
		\d+\spt					# score
		\s+\|\s+
		\d+\.\d+\s%			# perfection (similarity to starter unit)
		\s+\|\s+
		\d+\smis				# # mismatches
		\s+\|\s+
		\d+\sins				# # insertions
		\s+\|\s+
		\d+\sdel				# # deletions
		\s+\|\s+
		\d+\sN					# # Ns
		\s+\|\s+
		unit\s([ATCGU]+) # unit sequence
		/x
		) {
		# length
		my $l = length($2);
		# sum up the bp count
		$bp{$l} += $1;
		# count up for this length
		$c{$l}++;
	}
}
close $fh;

# megabasepairs total
my $mbp = $n / 1000000;

# header line
print "unit length,count,bp,bppmbp\n";

foreach my $l (sort { $a <=> $b } keys %c) {
	# bp per mbp
	my $bppmbp = $bp{$l} / $mbp;

	# length, count, bp, bp/Mbp
	printf "%d,%d,%d,%.2f\n", $l, $c{$l}, $bp{$l}, $bppmbp;
}
