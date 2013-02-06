#!/usr/bin/perl
use strict;
use warnings;
use Benchmark;
use IO::File;

my $string = shift;
my $estfile = shift or die "2 args plz\n";

open(my $fh, '<', $estfile) or die "$!\n";
my @ests = <$fh>;
close $fh;

for (my $i = 10; $i < 100001; $i = $i * 10) {
	my $bench = timethese($i,
		{	#'IOFile' => \&_iofile,
			#'sed' => \&_sed,
			#'subst' => \&_subst
			'whilereadline' => \&_while,
			'grep'  => \&_grep,
			#'grep_system' => \&_grep_system,
			#'foreach' => \&_foreach,
			'foreachfrommemory' => \&foreach2,
		}
	);
}


sub foreach2 {
	foreach(@ests) {
		if ($_ =~ /$string/) {
			return $_;
			last;
		}
	}
}
	

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

sub _grep_P {
	`grep -P -m 1 -c $string $estfile`;
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

sub _sed {
	`sed -e 's/\ /_/' $estfile > $estfile.out`;
}

sub _subst {
	open (my $fh, '<', $estfile) or die "I'm sorry, but I could not open the file, Sir.\n";
	open (my $outfh, '>', "$estfile.out") or die "I'm sorry, but I could not open the file, Sir.\n";
	while (<$fh>) {
		chomp;
		s/\+/_/g;
		print $outfh $_ . "\n";
	}
	close $fh;
	close $outfh;
}
