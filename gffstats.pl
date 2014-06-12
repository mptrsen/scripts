#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use File::Basename;
use Data::Dumper;

my $usage = "$0 GFFFILE\n";

if (scalar @ARGV == 0) { print $usage and exit }

my $big_data_structure = { };

foreach my $inf (@ARGV) {

	$big_data_structure->{basename($inf)} = get_gff_data($inf);

}

while (my ($fn, $d) = each %$big_data_structure) {
	print 'Statistics for ' . $fn . "\n";
	print '---------------' . '-' x length($fn) . "\n\n";
	print_gff_statistics($d);
}

exit;

#
# functions follow
#
sub get_gff_data {
	my $f = shift;
	open my $fh, '<', $f;
	my $d = { };
	while (<$fh>) {
		if (/^#/) {
			last if /^##FASTA/;
			next;
		}
		my @f = split /\s+/;
		$d->{$f[1]}->{$f[2]}->{'count'}++;

		if (/AED=(\d\.\d+);_eAED=(\d\.\d+)/) {
			if ($1 > 0.5) {
				$d->{$f[1]}->{$f[2]}->{'AED_above_threshold'}++;
			}
			else {
				$d->{$f[1]}->{$f[2]}->{'AED_below_threshold'}++;
			}
		}
	}
	close $fh;
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
	my $s = 0;

	# add up
	foreach my $pk (sort keys %$d) {
		my $s = 0;
		foreach my $sk (keys %{$d->{$pk}}) {
			$sources->{$pk}->{'count'}     += $d->{$pk}->{$sk}->{'count'};
			$types->{$sk}->{'count'}       += $d->{$pk}->{$sk}->{'count'};
			$uniqs->{"$pk+$sk"}->{'count'} += $d->{$pk}->{$sk}->{'count'};
			$sum_sources                   += $d->{$pk}->{$sk}->{'count'};
			$sum_types                     += $d->{$pk}->{$sk}->{'count'};
			$sum_total                     += $d->{$pk}->{$sk}->{'count'};
			if ($d->{$pk}->{$sk}->{'AED_above_threshold'}) {
				$types->{$sk}->{'AED_above_threshold'}       += $d->{$pk}->{$sk}->{'AED_above_threshold'};
				$types->{$sk}->{'AED_below_threshold'}       += $d->{$pk}->{$sk}->{'AED_below_threshold'};
				$uniqs->{"$pk+$sk"}->{'AED_above_threshold'} += $d->{$pk}->{$sk}->{'AED_above_threshold'};
				$uniqs->{"$pk+$sk"}->{'AED_below_threshold'} += $d->{$pk}->{$sk}->{'AED_below_threshold'};
			}
		}
	}


	print "Feature sources:\n";
	foreach my $k (sort keys %$sources) {
		printf "\t%s, %d, %.2f%%\n", $k, $sources->{$k}->{'count'}, $sources->{$k}->{'count'} / $sum_sources * 100;
		$s += $sources->{$k}->{'count'} / $sum_sources * 100;
	}
	print_sum($s);

	$s = 0;

	print "Feature types:\n";

	foreach my $k (sort keys %$types) {
		if ($types->{$k}->{'AED_above_threshold'}) {
			printf "\t%s, %d, %.2f%%\n\t\t%s, %d, %.2f%%\n\t\t%s, %d, %.2f%%\n",
				$k,
				$types->{$k}->{'count'},
				$types->{$k}->{'count'} / $sum_types * 100,
				'AED above threshold',
				$types->{$k}->{'AED_above_threshold'},
				$types->{$k}->{'AED_above_threshold'} / ($types->{$k}->{'AED_above_threshold'} + $types->{$k}->{'AED_below_threshold'}) * 100,
				'AED below threshold',
				$types->{$k}->{'AED_below_threshold'} ,
				$types->{$k}->{'AED_below_threshold'} / ($types->{$k}->{'AED_above_threshold'} + $types->{$k}->{'AED_below_threshold'}) * 100,
			;
			$s += $types->{$k}->{'count'} / $sum_types * 100;

		}
		else {
			printf "\t%s, %d, %.2f%%\n", $k, $types->{$k}->{'count'}, $types->{$k}->{'count'} / $sum_types * 100;
			$s += $types->{$k}->{'count'} / $sum_types * 100;
		}
	}
	print_sum($s);

	$s = 0;

	print "Unique combinations:\n";

	foreach my $pk (sort keys %$d) {
		foreach my $sk (sort keys %{$d->{$pk}}) {
			my $comb = $uniqs->{"$pk+$sk"};

			if ($comb->{'AED_above_threshold'}) {
				printf "\t%s + %s, %d, %.2f%%\n\t\t%s, %d, %.2f%%\n\t\t%s, %d, %.2f%%\n",
					$pk,
					$sk,
					$comb->{'count'},
					$comb->{'count'} / $sum_total * 100,
					'AED above threshold',
					$comb->{'AED_above_threshold'},
					$comb->{'AED_above_threshold'} / ($comb->{'AED_above_threshold'} + $comb->{'AED_below_threshold'}) * 100,
					'AED below threshold',
					$comb->{'AED_below_threshold'} ,
					$comb->{'AED_below_threshold'} / ($comb->{'AED_above_threshold'} + $comb->{'AED_below_threshold'}) * 100,
				;
				$s += $comb->{'count'} / $sum_total * 100;
			}
			else {
				printf "\t%s + %s, %d, %.2f%%\n",
					$pk,
					$sk,
					$comb->{'count'},
					$comb->{'count'} / $sum_total * 100,
				;
				$s += $comb->{'count'} / $sum_total * 100;
			}
		}
	}

	print_sum($s);
	$s = 0;
}

sub print_sum {
	printf "\t----------------------------------------------\n\tSum: %.2f %%\n", $_[0];
	print "\n";
}
