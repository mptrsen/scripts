#!/usr/bin/perl
use strict;
use warnings;

use Data::Dumper;
use Seqload::Fasta;
use File::Temp;     # temporary files
use IO::File;       # object-oriented access to files

my %taxa;	# store taxon info
my $eogfile;

my $logfile = IO::File->new(shift(@ARGV));

# read the logfile, extract infos
while (my $line = <$logfile>) {
	chomp $line;
	next if $line =~ /^\s*$/;	# skip empty lines
	if ($line =~ /EOG4/) {
		($eogfile = $line) =~ s/://;
		$taxa{$eogfile} = [ ];	# anon array to store list of outlier taxa
	}
	elsif ($line =~ /^\U[A-Z]\E/) {
		$line =~ s/\s.*//;	# delete everything after the taxname
		push(@{$taxa{$eogfile}}, $line);
	}
}

$logfile->close();

# ok we got all the info from the logfile. now take each of the eogfiles

foreach my $eogfn (keys(%taxa)) {
	my $fh = Seqload::Fasta->open($eogfn);
	while (my ($h, $s) = $fh->next_seq()) {
		foreach (@{$taxa{$eogfn}}) {
			print "yeah, it's here: $_\n" if ($h =~ /$_/);
		}
	}
}
exit;
