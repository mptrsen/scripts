#!/usr/bin/perl
use strict;
use warnings;

use SGML::Parser::OpenSP;

my $file = shift @ARGV;

die "Usage: $0 SGMLFILE\n" unless $file;

my $p = SGML::Parser::OpenSP->new;

my $h = SwissProtHandler->new;

$p->handler($h);
$p->parse($file);

package SwissProtHandler;

use Data::Dumper;
our $is_ac = 0;
our $is_seq = 0;
our $seq = '';
our $ac = '';
our $n = 0;
our @acs = ( );

sub new { bless {}, shift }

sub start_element {
	my ($self, $elem) = @_;
	if ($elem->{Name} eq 'AC') {
		$is_ac = 1;
	}
	elsif ($elem->{Name} eq 'SEQ') {
		$is_seq = 1;
	}
}

sub end_element {
	my ($self, $elem) = @_;
	if ($elem->{Name} eq 'AC') {
		$is_ac = 0;
	}
	elsif ($elem->{Name} eq 'E') {
		foreach (@acs) { printf ">%s\n%s\n", $_, $seq }
		@acs = ();
		$seq = '';
		$is_seq = 0;
	}
}

sub data {
	my ($self, $elem) = @_;
	return if $elem->{Data} =~ /^\s*$/;
	if ($is_ac) {
		$ac = $elem->{Data};
		$ac =~ s/;$//;
		push @acs, $ac;
		if ($ac =~ /P49523/) { print STDERR "got P49523\n" }
	}
	elsif ($is_seq) {
		$seq .= $elem->{Data};
		if ($ac =~ /P49523/) { print STDERR "got seq '$seq'\n" }
	}
}

