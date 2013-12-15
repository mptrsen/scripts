#!/usr/bin/perl
for (my $i=0; $i<10000; ++$i) {
	open(my $fh, 'test.txt') or die;
	my $line = <$fh>;
	close $fh;
	$line =~ s/blah/hullu/;
	$line =~ s/hullu/blah/;
	open($fh, '>test.txt') or die;
	print $fh $line;
	close $fh;
}
