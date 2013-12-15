#!/usr/bin/perl
my ($searchstring, $infile) = @ARGV;
for (my $i = 0; $i < 10000; ++$i) {
	my @result;
	open(my $lines, $infile) or die;
	open(my $dump, '>/dev/null') or die;
	while (<$lines>) {
		print $dump $_ if /$searchstring/;
	}
	close $infile;
	close $dump;
}
