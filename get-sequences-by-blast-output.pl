#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use lib '/home/mpetersen/scripts';
use Blast::ParseTable;
use Seqload::Fasta;
use Data::Dumper;

my $infile = shift @ARGV or die "Usage: $0 BLASTREPORT GENOMEFILE\n";
my $genome = shift @ARGV or die "Usage: $0 BLASTREPORT GENOMEFILE\n";

my $hits = { };

my $report = Blast::ParseTable->new($infile);

while (my $hit = $report->next_hsp()) {
	my $target  = $hit->{'subject id'};
	my $query   = $hit->{'query id'};
	my $qstart  = $hit->{'q. start'} < $hit->{'q. end'} ? $hit->{'q. start'} : $hit->{'q. end'};
	my $qend    = $hit->{'q. start'} < $hit->{'q. end'} ? $hit->{'q. end'}   : $hit->{'q. start'};
	my $tstart  = $hit->{'s. start'} < $hit->{'s. end'} ? $hit->{'s. start'} : $hit->{'s. end'};
	my $tend    = $hit->{'s. start'} < $hit->{'s. end'} ? $hit->{'s. end'}   : $hit->{'s. start'};
	#--------------------------------------------------
	# printf "%s[%d-%d] found for %s[%d-%d] (len %d)\n",
	# 	$target,
	# 	$tstart,
	# 	$tend,
	# 	$query,
	# 	$qstart,
	# 	$qend,
	# 	$tend - $tstart + 1,
	# ;
	#-------------------------------------------------- 
	# this hsp exists?
	if (defined $hits->{$query} and defined $hits->{$query}->{$target}) {
		# identical coordinates?
		if ($hits->{$query}->{$target}->{'q. start'} == $qstart and
			  $hits->{$query}->{$target}->{'q. end'}   == $qend   and
			  $hits->{$query}->{$target}->{'s. start'} == $tstart and
			  $hits->{$query}->{$target}->{'s. end'}   == $tend
		) {
			# skip this one
			next;
		}
	}
	# this hsp exists in reverse orientation?
	elsif (defined $hits->{$target} and defined $hits->{$target}->{$query}) {
		# identical coordinates?
		if ($hits->{$target}->{$query}->{'q. start'} == $qstart and
			  $hits->{$target}->{$query}->{'q. end'}   == $qend   and
			  $hits->{$target}->{$query}->{'s. start'} == $tstart and
			  $hits->{$target}->{$query}->{'s. end'}   == $tend
		) {
			# skip this one
			next;
		}
	}
	# otherwise, continue and add to data structure
	foreach my $field ($report->fields()) {
		$hits->{$query}->{$target}->{$field} = $hit->{$field};
	}
}

my $fh = Seqload::Fasta->open($genome);
while (my ($h, $s) = $fh->next_seq()) {
	$h =~ s/\s.+$//;
	$h =~ s/\.1$//;
	foreach my $hit (keys %{$hits->{$h}}) {
		my $start = $hits->{$h}->{$hit}->{'q. start'} - 1;
		my $end = $hits->{$h}->{$hit}->{'q. end'} - 1;
		my $length = $end - $start + 1;
		printf ">%s[%d-%d] on %s[%d-%d]\n%s\n",
			$h,
			$hits->{$h}->{$hit}->{'q. start'},
			$hits->{$h}->{$hit}->{'q. end'},
			$hits->{$h}->{$hit}->{'subject id'},
			$hits->{$h}->{$hit}->{'s. start'},
			$hits->{$h}->{$hit}->{'s. end'},
			substr($s, $start, $length),
		;
	}
}

