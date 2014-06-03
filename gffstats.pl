#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use File::Basename;
use Data::Dumper;

my $usage = "$0 GFFFILE\n";

if (scalar @ARGV == 0) { print $usage and exit }

foreach my $inf (@ARGV) {

	my $data = get_gff_data($inf);
	print_gff_statistics($data);

}

sub get_gff_data {
	my $f = shift;
	open my $fh, '<', $f;
	my $d = { };
	while (<$fh>) {
		next if /^#/;
		my @f = split /\s+/;
		$d->{$f[1]}->{$f[2]}++;

		if (/AED=(\d\.\d+);_eAED=(\d\.\d+)/) {
			if ($1 > 0.5) {
				$d->{$f[1]}->{'AED_above_threshold'}++;
			}
			else {
				$d->{$f[1]}->{'AED_below_threshold'}++;
			}
		}
	}
	close $fh;
	print 'Statistics for ' . basename($f) . "\n";
	print '---------------' . '-' x length(basename($f)) . "\n";
	return $d;
}

sub print_gff_statistics {
	my $d           = shift;
	my $types       = {};
	my $sources     = {};
	my $uniqs       = {};
	my $sum_sources = 0;
	my $sum_types   = 0;
	my $sum_total   = 0;

	# add up
	foreach my $pk (sort keys %$d) {
		my $s = 0;
		foreach my $sk (keys %{$d->{$pk}}) {
			$sources->{$pk}     += $d->{$pk}->{$sk};
			$types->{$sk}       += $d->{$pk}->{$sk};
			$uniqs->{"$pk+$sk"} += $d->{$pk}->{$sk};
			$sum_sources        += $d->{$pk}->{$sk};
			$sum_types          += $d->{$pk}->{$sk};
			$sum_total          += $d->{$pk}->{$sk};
		}
	}

	print "Feature sources:\n";
	foreach my $k (sort keys %$sources) {
		printf "\t%s, %d, %.2f%%\n", $k, $sources->{$k}, $sources->{$k} / $sum_sources * 100;
	}

	print "Feature types:\n";
	my $aed_above = $types->{'AED_above_threshold'};
	my $aed_below = $types->{'AED_below_threshold'};

	foreach my $k (sort keys %$types) {
		if ($k =~ /^mRNA/) {
			printf "\t%s, %d, %.2f%%\n\t\t%s, %d, %.2f%%\n\t\t%s, %d, %.2f%%\n",
				$k,
				$types->{$k},
				$types->{$k} / $sum_types * 100,
				'AED below threshold',
				$aed_above,
				$aed_above / $sum_types * 100,
				'AED below threshold',
				$aed_below,
				$aed_below / $sum_types * 100,
			;
		}
		else {
			printf "\t%s, %d, %.2f%%\n", $k, $types->{$k}, $types->{$k} / $sum_types * 100
				unless $k =~ /^AED/;
		}
	}

	print "Unique combinations:\n";

	foreach my $pk (sort keys %$d) {
		foreach my $sk (keys %{$d->{$pk}}) {
			if ($sk =~ /^mRNA/) {
				printf "\t%s + %s, %d, %.2f%%\n\t\t%s, %d, %.2f%%\n\t\t%s, %d, %.2f%%\n",
					$pk,
					$sk,
					$uniqs->{"$pk+$sk"},
					$uniqs->{"$pk+$sk"} / $sum_total * 100,
					'AED below threshold',
					$aed_above,
					$aed_above / $sum_total * 100,
					'AED below threshold',
					$aed_below,
					$aed_below / $sum_total * 100,
				;
			}
			else {
				printf "\t%s + %s, %d, %.2f%%\n",
					$pk,
					$sk,
					$uniqs->{"$pk+$sk"},
					$uniqs->{"$pk+$sk"} / $sum_total * 100,
						unless $sk =~ /^AED/
				;
			}
		}
	}
	print "\n";
}
