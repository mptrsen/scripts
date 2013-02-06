#!/usr/bin/perl
use strict;
use warnings;
use Path::Class;
use File::Spec;
use File::Basename;
use Data::Dumper;

# complain unless correct # of args
die "need 2 args: ntdir aadir\n" unless (scalar @ARGV == 2);
my ($aadir, $ntdir) = @ARGV;

# open directories, read content, filter out dotfiles
my $ntfiles = &getdircontents(dir($ntdir));
my $aafiles = &getdircontents(dir($aadir));

# filter out cds files
@$ntfiles = grep( !-d, @$ntfiles);

# die if number of files differ
if (scalar @$aafiles != scalar @$ntfiles) {
	die 'number of relevant files in ', dir($aadir), ' and ', dir($ntdir), ' differ!', "\n", 
}

# go through the nt files
$| = 1;
foreach my $ntfile (@$ntfiles) {
	my ($ntlines, $aalines);
	(my $aafilename = basename($ntfile)) =~ s/\.nt//;

	$ntlines = &readfile(file($ntdir, $ntfile));

	die "nt lines != 2!" unless (scalar @$ntlines == 2);

	# open corresponding aa file
	$aalines = &readfile(file($aadir, $aafilename));
	
	print "checking $aafilename : $ntfile ... ";

	# not OK if lengths differ
	my $aalen = length $$aalines[-1];
	printf "% 6d : ", $aalen;
	my $ntlen = length $$ntlines[-1];
	printf "%-6d ", $ntlen;
	if ($aalen != $ntlen/3) {
		die "inequal lengths: $$aalines[-2] and $$ntlines[-2] differ!\n";
	}
	# otherwise fine
	print "OK\n";
}
$| = 0;
printf "sequence lengths in '%s' and '%s' correspond.\n", basename(dir($ntdir)), basename(dir($aadir));

# everything OK
exit;

#--------------------------------------------------
# # Functions follow
#-------------------------------------------------- 

sub readfile {
	my $file = shift;

	open(my $fh, '<', file($file)) or die "Fatal: Could not open ", file($file), ": $!";
	my @lines = <$fh>;
	close $fh;

	chomp @lines;
	return \@lines;
}

sub getdircontents {
	my $dir = shift;

	opendir(my $dirh, dir($dir)) or die "$!";
	my @content = readdir($dirh);
	closedir $dirh;

	@content = grep( !/^\.+/, @content );
	chomp @content;
	return \@content;
}

sub dna2aa {
# TODO LOTS OF TRANSLATION HERE
}
