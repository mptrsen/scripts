#!/usr/bin/perl
use strict;
use warnings;

use Seqload::Fasta;
use Getopt::Long;
use Data::Dumper;

my $listfile;
my $ogsfile;
my %proteome_of;
my $ids = { };
my $match;
my $total;
my $seqs;

GetOptions('l=s' => \$listfile, 'o=s' => \$ogsfile);

#--------------------------------------------------
# Step 1: Read the taxa list file, store TAX->file information in a hash
#-------------------------------------------------- 
open(my $lfh, '<', $listfile) or die("Could not open list file $listfile: $!\n");
while (<$lfh>) {
	next if /^\s*$/;
	next if /^\s*#/;
	my @fields = split();
	chomp(@fields);
	$proteome_of{$fields[0]} = $fields[1];
	$$ids{$fields[0]} = [ ] unless exists($$ids{$fields[0]});
}
close($lfh) or die($!);
# printf "%s %s\n", $_, $proteome_of{$_} foreach keys %proteome_of;

#--------------------------------------------------
# Step 2: Read through the orthologous sequences file, store TAX->IDs (as array) in another hash
#-------------------------------------------------- 
my $ogsfh = Seqload::Fasta->open($ogsfile);
while(my ($hdr, $seq) = $ogsfh->next_seq()) {
	my @fields = split(/\s+/, $hdr);
	my @subfields = split(/\|/, $fields[3]) if $fields[3] =~ /\|/;
	chomp(@fields, @subfields);
	my $tax = substr($fields[1], 0, 5);
	next unless grep(/$tax/, keys(%proteome_of));
	# $ids->{$tax}{$fields[2]} = 1;	# ?
	scalar(@subfields) > 1 ? push(@{$ids->{$tax}}, $subfields[0]) : push(@{$ids->{$tax}}, $fields[2]);
}
$ogsfh->close();

printf("%d headers for %s in %s\n", scalar(@{$ids->{$_}}), $_, $proteome_of{$_}) foreach(sort(keys(%proteome_of)));
print "\n";

#--------------------------------------------------
# Step 3: For each file and every header, compare IDs (this takes very long)
#-------------------------------------------------- 
foreach my $id (sort(keys(%$ids))) {
	$match = 0;
	$seqs = 0;
	$total = scalar(@{$ids->{$id}});
	$| = 1;
	print 'checking ', $id, ' (', $proteome_of{$id} , ")... ";
	$| = 0;
	my $fh = Seqload::Fasta->open($proteome_of{$id});
	while (my ($hdr, $seq) = $fh->next_seq()) {
		++$seqs;
		my @fields = split(/\s+/, $hdr);
		#if (exists($$ids{$id}{$fields[0]}) {	# ?
		for (my $i = 0; $i < scalar(@{$ids->{$id}}); ++$i) {
			if ($fields[0] =~ /^\Q$$ids{$id}[$i]\E$/) {
				++$match;
				# at least splice the array to make future searches faster
				splice(@{$ids->{$id}}, $i, 1);
				last;
			}
		}
	}
	$fh->close();
	if ($total != $match) {
		warn "Didn't find all $total orthologous sequences (only $match) in $seqs sequences of $proteome_of{$id}\n";
		warn "Missing:\n";
		warn "\t$_\n" foreach @{$ids->{$id}};
		}
	else {
		print "OK ($seqs seqs checked, found all $total headers)\n";
	}
}
