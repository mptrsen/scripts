#!/usr/bin/perl
use strict;
use warnings;

use Carp; 

sub parse_config {
	my $file = shift;
	my $conf = { };
	open(my $fh, '<', $file) or die "$!\n";

	while (my $line = <$fh>) {
		next if $line =~ /^\s*$/;	# skip empty lines
		
		# split by '=' producing a maximum of two items
		my ($key, $val) = split('=', $line, 2);

		foreach ($key, $val) {
			s/\s+$//;	# remove all trailing whitespace
			s/^\s+//;	# remove all leading whitespace
		}

		croak "Fatal: Configuration option '$key' defined twice in line $. of config file $file\n"
			if defined $conf->{$key};
		$conf->{$key} = $val;
	}
	close($fh);
	return $conf;
}

my $config = &parse_config($ARGV[0]);
while (my @i = each %$config) {
	print join(" ", @i) . "\n";
}
