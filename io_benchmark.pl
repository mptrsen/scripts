#!/usr/bin/perl
use strict;
use warnings;
use Benchmark;
use IO::File;

my $string = shift;
my $estfile = shift or die "2 args plz\n";

my $bench = timethese(1000, 
	{	#'IOFile' => \&_iofile,
		'while' => \&_while,
		'grep'  => \&_grep,
		'grep_system' => \&_grep_system,
		#'foreach' => \&_foreach
	}
);


sub _iofile {
	my $fh = IO::File->new();
	$fh->open($estfile) or die "I'm sorry, but I could not open the file, Sir.\n";
	my @lines = <$fh>;
	$fh = undef;
	foreach(@lines) {
		if ($_ =~ /$string/) {
			return $_;
			last;
		}
	}
	@lines = ();
}

sub _while {
	open(my $fh, '<', $estfile) or die "I'm sorry, but I could not open the file, Sir.\n";
	while (<$fh>) {
		if ($_ =~ /$string/) {
			return $_;
			last;
		}
	}
	close($fh);
}

sub _grep {
	`grep -m 1 -c $string $estfile`;
}

sub _grep_system {
	system("grep -m 1 -c $string $estfile > /dev/null");
}

sub _foreach {
	open(my $fh, '<', $estfile) or die "I'm sorry, but I could not open the file, Sir.\n";
	my @lines = <$fh>;
	close($fh);
	foreach(@lines) {
		if ($_ =~ /$string/) {
			return $_;
			last;
		}
	}
	@lines = ();
}
