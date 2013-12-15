#!/usr/bin/perl
use strict;

my $aadir = $ARGV[0];
my $dnadir = $ARGV[1];
my @dnafiles;
my @aafiles;
my $resultsdir = $ARGV[2];
my $gw = '/share/scientific_bin/wise/bin/genewise';
unless (scalar @ARGV == 3) {
	die <<EOF;
Usage: $0 <aadir> <dnadir> <resultdir>
EOF
}

unless (-e $resultsdir) {
  mkdir($resultsdir) or die "mkdir: $!\n";
}


opendir(my $dnafiles, $dnadir) or die "opendir: $!\n";
while (my $dnafile = readdir($dnafiles)) {
	push(@dnafiles, $dnafile) unless $dnafile =~ /^\.\.?/;
}
closedir $dnafiles;
@dnafiles = sort @dnafiles;

opendir(my $aafiles, $aadir) or die "opendir: $!\n";
while (my $aafile = readdir($aafiles)) {
	push(@aafiles, $aafile) unless $aafile =~ /^\.\.?/;
}
closedir $aafiles;
@aafiles = sort @aafiles;

foreach my $aafile (@aafiles) {
		(my $aaoutfile = $aafile) =~ s/(.*\/)*//;
		foreach my $dnafile (@dnafiles) {
			(my $dnaoutfile = $dnafile) =~ s/(.*\/)*//;
			my $gwcmdline = "$gw -trans -cdna -pep -sum $aadir/$aafile $dnadir/$dnafile >> $resultsdir/$aaoutfile.gwresult";
			print $gwcmdline, "\n";
			`$gwcmdline` and warn "gw failed on file $aafile and $dnafile\: $!\n";
		}
}

