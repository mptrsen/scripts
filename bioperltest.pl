#!/usr/bin/perl
use strict;
use warnings;

use Bio::SearchIO; 
use Bio::DB::Fasta;


my ($file,$id,$start,$end) = ($ARGV[0],"C7136661:0-107",1,10);
my $db = Bio::DB::Fasta->new($file);
$db->id_parser(\&get_id);
my $seq = $db->seq($id,$start,$end);
print $seq,"\n";

sub get_id {
	my $header = shift;
	$header =~ /^>.*\b(\w+)\b/;
	return $1;
}
