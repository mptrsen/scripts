#!/usr/bin/perl

#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#  
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
#  MA 02110-1301, USA.
#  




use strict          ;
use warnings        ;

my $file_counter = 0;
my $genes_outlier= 0;


# reads list of taxa of interest, not reference taxa of core ortholg sets, 
# these taxa of interests have to be assembled in flat lists, for example 
# a set of our transcriptome taxa could be in this list

open my $subject_file,"<",'subjects.txt';
my @subject=<$subject_file>;
chomp @subject;
close $subject_file;

open my $log,">",'log.txt';
open my $outlier,">","outlier.txt";
print {$outlier} 'genes with outliers',"\n";


print "\n",'checking files',"\n";

while (<*.fas>){

# local list of taxa of interest as keys and specific reference taxa to 
# this taxon of interest as value
	my %subject_local=();

# local list of all reference taxa from which median hamming distances 
# will be calculated	
	my @reference_taxa=();

# local reference taxa drawn from the fasta file to which reference taxa
# should be compared in hamming distances, allways a subset of the 
# @reference_taxa list	

	my @query_local=();

	$file_counter ++ ;
	my $file =$_;

	my ($ref_FASTA, $ref_al_length) = &read_FASTA($file);
	my $ntaxa = keys %$ref_FASTA ;
	
	printf "\nfile: %-20.20s\talignment length: %-10.10s\n", $file,$$ref_al_length;
	printf {$log} "\nfile: %-20.20s\talignment length: %-10.10s\n", $file,$$ref_al_length;

# pushes all taxa which do not belong to the list of taxa of interest into
# a reference list, with this list, a median distance value and variance 
# of the expected hamming distances will be calculated

	for my $reference_taxa (keys %$ref_FASTA){
			push @reference_taxa, $reference_taxa if !grep/$reference_taxa/,@subject
	}
	my $transcriptomes = $ntaxa - @reference_taxa ;


# reads full names of taxa of interest from the fasta file and stores these
# full names in a hash as keys only for the present file with the name of
# the reference taxon to be compared with as value of this key, if a taxon
# of interest is not present in the fasta file, it will not be stored in
# the subject_local file, nothing will be stored for this taxon, also no key

	for my $taxon (@subject){
		for (keys %$ref_FASTA){
			next if 2 == tr/\|/\|/ ;
			my @array=split/\Q|\E/; 
			if ($taxon eq $array[2]){
				my $taxon_full=$_;
				for (keys %$ref_FASTA){
					if (2 == tr/\|/\|/ and /$array[1]/){
						push @query_local, $_ if !grep/$array[1]/,@query_local;
						$subject_local{$taxon_full}=$_;
						last;
					}
				}
			}
		}
	}


	for my $taxon (@subject){
		if (!grep/$taxon/,keys %subject_local){
			printf "%-30.30s\t%-10.10s\n", $taxon,'missing';
			printf {$log} "%-30.30s\t%-10.10s\n", $taxon,'missing';
		}
	}

	printf "%-30.30s\t%-10.10s\n",'total number of taxa:', $ntaxa;
	printf "%-30.30s\t%-10.10s\n",'transcriptomes:', $transcriptomes;
	printf {$log} "%-30.30s\t%-10.10s\n",'total number of taxa:', $ntaxa;
	printf {$log} "%-30.30s\t%-10.10s\n",'transcriptomes:', $transcriptomes;

# projects coordinates of taxon of interest onto reference taxon, goes 
# through all taxa of interests and derives the section of consensus overlap
# for all taxa of interest; only for this section of the alignment, distance
# calculations for all comparisons will be performed, this sequence length 
# should be given in the log file and on the screen

	my ($start,$end)=($$ref_al_length,0);

	for my $taxon(keys %subject_local){
		my ($s,$e)=&indices($taxon,$subject_local{$taxon},$ref_al_length,$ref_FASTA);
		$start = $s < $start ? $s :  $start ;
		$end = $e > $end ? $e : $end ;
	}

	printf "%-30.30s\t%-10.10s\n\n",'overlap length: ', $end-$start;
	printf {$log} "%-30.30s\t%-10.10s\n\n",'overlap length: ', $end-$start;

	printf "%-6.6s\t%-6.6s\t%-6.6s\t%-6.6s\t%-6.6s\n",'min','max','median','Q1','Q3';
	printf {$log} "%-6.6s\t%-6.6s\t%-6.6s\t%-6.6s\t%-6.6s\n",'min','max','median','Q1','Q3';
	
# calculates match/missmatch distances for all reference taxa in the alignment within the
# section of overlap; indel and X positions are ignored in each pair separately!
# works for nucleotide and aminoacid data in both cases match/missmatch distances

	my $ref_scoring = &BLOSUM_scoring;

	my @dissimilarities=();
	
	while ( 1 < @reference_taxa){
		my $taxon = shift@reference_taxa;
		for (@reference_taxa){
			my ($dist)=&BLOSUM_dist($taxon,$_,[$start..$end],$ref_FASTA,$ref_scoring);
			push @dissimilarities, $dist
		}
	}
		
# uses distances to calculate median, min, max, quartiles and whiskers
		
	@dissimilarities =  sort{$a<=>$b}@dissimilarities;
	my $median_dissi =&median(\@dissimilarities);
	   $median_dissi = 1 if $median_dissi == 0 ;
	
	my $dist_min     =  $dissimilarities[0];
	my $dist_max     =  $dissimilarities[-1]; 
	my ($Q1,$Q3,$W1,$W3);
	
		if (@dissimilarities%2 ==1){
			$Q1=&median([@dissimilarities[0..((@dissimilarities+1)/2)-2]]);
			$Q3=&median([@dissimilarities[((@dissimilarities+1)/2)..$#dissimilarities]])
		}
		else{
			$Q1=&median([@dissimilarities[0..((@dissimilarities+1)/2)-1]]);
			$Q3=&median([@dissimilarities[((@dissimilarities+1)/2)..$#dissimilarities]])
		}
		$W1= $median_dissi-1.5*($median_dissi-$Q1) < 0 ? 0 : $median_dissi-1.5*($median_dissi-$Q1);
		$W3= $median_dissi+1.5*($Q3-$median_dissi) > $dist_max ? $dist_max : $median_dissi+1.5*($Q3-$median_dissi);

	printf "%-6.6s\t%-6.6s\t%-6.6s\t%-6.6s\t%-6.6s\n\n",$dist_min,$dist_max,$median_dissi,$Q1,$Q3;
	printf {$log} "%-6.6s\t%-6.6s\t%-6.6s\t%-6.6s\t%-6.6s\n\n",$dist_min,$dist_max,$median_dissi,$Q1,$Q3;
		

# calculates match/missmatch distance for closest reftaxon only for consensus 
# overlap length of the alignment and collects them in a hash

	my %BLOSUM_dist_of = ();

	for my $taxon(keys %subject_local){
		my @taxon = split/\Q|\E/,$taxon;
		$BLOSUM_dist_of{$taxon}=&BLOSUM_dist($taxon,$subject_local{$taxon},[$start..$end],$ref_FASTA,$ref_scoring);
	}
	
# calculates median, quartiles and whiskers of the transcriptome distances
# and uses W3 upper whiskers as cutoff for outliers
# outliers are therefore not dedected by reference to the reftaxa but by
# a strong deviation of transcriptome taxa from the median transcriptome distance 	

	#my @transcriptome_distances = sort{$a<=>$b}values %hamming_dist_of;
	#my $outlier_cutoff = &outlier( \@transcriptome_distances );
	my $outlier_cutoff = &outlier( \@dissimilarities );
	
	printf "%-30.30s\t%-10.10s\n\n",'transcriptome outlier dist: >', $outlier_cutoff;
	printf {$log} "%-30.30s\t%-10.10s\n\n",'transcriptome outlier dist: >', $outlier_cutoff;

	printf  "%-20.20s\t%-6.6s\t%-6.6s\n",'taxon','dist','re.dist';
	printf {$log}"%-20.20s\t%-6.6s\t%-6.6s\n",'taxon','dist','re.dist';
	
	my $flag_outlier = 0 ;
	my $count_outlier = 0 ;
	
	for my $taxon(keys %BLOSUM_dist_of){

		my @taxon = split/\Q|\E/,$taxon;
					
		if ($BLOSUM_dist_of{$taxon} > $outlier_cutoff and $flag_outlier == 0){
			$flag_outlier = 1 ;
			$count_outlier++;
			printf {$outlier} "\n$file:\n";
			printf {$outlier} "%-6.6s\t%-6.6s\t%-6.6s\t%-6.6s\t%-6.6s\n",'min','max','median','Q1','Q3';
			printf {$outlier} "%-6.6s\t%-6.6s\t%-6.6s\t%-6.6s\t%-6.6s\n\n",$dist_min,$dist_max,$median_dissi,$Q1,$Q3;
			printf  "%-20.20s\t%-6.6s\t%-6.6s\t%-6.6s\n","$taxon[2] = ",$BLOSUM_dist_of{$taxon},$BLOSUM_dist_of{$taxon}/$median_dissi,'out!' ;
			printf {$log} "%-20.20s\t%-6.6s\t%-6.6s\t%-6.6s\n","$taxon[2] = ",$BLOSUM_dist_of{$taxon},$BLOSUM_dist_of{$taxon}/$median_dissi,'out!';
			printf {$outlier} "%-20.20s\t%-6.6s\t%-6.6s\t%-6.6s\n","$taxon[2] = ",$BLOSUM_dist_of{$taxon},$BLOSUM_dist_of{$taxon}/$median_dissi,'out!';
		}
		elsif ($BLOSUM_dist_of{$taxon} > $outlier_cutoff and $flag_outlier == 1){
			$count_outlier++;
			printf  "%-20.20s\t%-6.6s\t%-6.6s\t%-6.6s\n","$taxon[2] = ",$BLOSUM_dist_of{$taxon},$BLOSUM_dist_of{$taxon}/$median_dissi,'out!' ;
			printf {$log} "%-20.20s\t%-6.6s\t%-6.6s\t%-6.6s\n","$taxon[2] = ",$BLOSUM_dist_of{$taxon},$BLOSUM_dist_of{$taxon}/$median_dissi,'out!';
			printf {$outlier} "%-20.20s\t%-6.6s\t%-6.6s\t%-6.6s\n","$taxon[2] = ",$BLOSUM_dist_of{$taxon},$BLOSUM_dist_of{$taxon}/$median_dissi,'out!';
		}
		else{
			printf  "%-20.20s\t%-6.6s\t%-6.6s\n","$taxon[2] = ",$BLOSUM_dist_of{$taxon},$BLOSUM_dist_of{$taxon}/$median_dissi;
			printf {$log} "%-20.20s\t%-6.6s\t%-6.6s\n","$taxon[2] = ",$BLOSUM_dist_of{$taxon},$BLOSUM_dist_of{$taxon}/$median_dissi;
		}
	}
	$genes_outlier++ if $flag_outlier == 1;
	print        "\n",'outliers counted: ',$count_outlier,"\n";
	print {$log} "\n",'outliers counted: ',$count_outlier,"\n"
}

print {$log} "\n $file_counter .fas files (genes) checked\n$genes_outlier .fas files with outliers\n";

print<<STAT;

total number of files checked: $file_counter
files with outliers:           $genes_outlier

STAT


#_____________________________________________________________________________________________________________________________________

sub outlier {

	my ($Q1,$Q3,$W1,$W3);
	my ($ref_array) = @_;
	@$ref_array =  sort{$a<=>$b}@$ref_array;
	my $dist_max = $$ref_array[-1];
	
	my $median = &median($ref_array);
	
		if (@$ref_array%2 ==1){
			$Q1=&median([@$ref_array[0..((@$ref_array+1)/2)-2]]);
			$Q3=&median([@$ref_array[((@$ref_array+1)/2)..$#$ref_array]])
		}
		else{
			$Q1=&median([@$ref_array[0..((@$ref_array+1)/2)-1]]);
			$Q3=&median([@$ref_array[((@$ref_array+1)/2)..$#$ref_array]])
		}
		$W1= $median-1.5*($median-$Q1) < 0 ? 0 : $median-1.5*($median-$Q1);
		$W3= $median+1.5*($Q3-$median) > $dist_max ? $dist_max : $median+1.5*($Q3-$median);
		
		return $dist_max*1.5
}	


sub median {
	my ($p)=@_;
	my $median = @$p%2 ==1 ? $$p[((@$p+1)/2)-1] : ($$p[(@$p/2)-1]+$$p[@$p/2])/2;
	return $median
}
	
sub BLOSUM_scoring {
		
		my %SCORING;

		#  Blosum62 source: NCBI
		#  Matrix made by matblas from blosum62.iij
		#  * column uses minimum score
		#  BLOSUM Clustered Scoring Matrix in 1/2 Bit Units
		#  Blocks Database = /data/blocks_5.0/blocks.dat
		#  Cluster Percentage: >= 62
		#  Entropy =   0.6979, Expected =  -0.5209
				
				my @BLOSUM62 =	(
				
						[ 4,-1,-2,-2, 0,-1,-1, 0,-2,-1,-1,-1,-1,-2,-1, 1, 0,-3,-2, 0,-2,-1, 0,-4 ],
						[-1, 5, 0,-2,-3, 1, 0,-2, 0,-3,-2, 2,-1,-3,-2,-1,-1,-3,-2,-3,-1, 0,-1,-4 ],
						[-2, 0, 6, 1,-3, 0, 0, 0, 1,-3,-3, 0,-2,-3,-2, 1, 0,-4,-2,-3, 3, 0,-1,-4 ],
						[-2,-2, 1, 6,-3, 0, 2,-1,-1,-3,-4,-1,-3,-3,-1, 0,-1,-4,-3,-3, 4, 1,-1,-4 ],
						[ 0,-3,-3,-3, 9,-3,-4,-3,-3,-1,-1,-3,-1,-2,-3,-1,-1,-2,-2,-1,-3,-3,-2,-4 ],
						[-1, 1, 0, 0,-3, 5, 2,-2, 0,-3,-2, 1, 0,-3,-1, 0,-1,-2,-1,-2, 0, 3,-1,-4 ],
						[-1, 0, 0, 2,-4, 2, 5,-2, 0,-3,-3, 1,-2,-3,-1, 0,-1,-3,-2,-2, 1, 4,-1,-4 ],
						[ 0,-2, 0,-1,-3,-2,-2, 6,-2,-4,-4,-2,-3,-3,-2, 0,-2,-2,-3,-3,-1,-2,-1,-4 ],
						[-2, 0, 1,-1,-3, 0, 0,-2, 8,-3,-3,-1,-2,-1,-2,-1,-2,-2, 2,-3, 0, 0,-1,-4 ],
						[-1,-3,-3,-3,-1,-3,-3,-4,-3, 4, 2,-3, 1, 0,-3,-2,-1,-3,-1, 3,-3,-3,-1,-4 ],
						[-1,-2,-3,-4,-1,-2,-3,-4,-3, 2, 4,-2, 2, 0,-3,-2,-1,-2,-1, 1,-4,-3,-1,-4 ],
						[-1, 2, 0,-1,-3, 1, 1,-2,-1,-3,-2, 5,-1,-3,-1, 0,-1,-3,-2,-2, 0, 1,-1,-4 ],
						[-1,-1,-2,-3,-1, 0,-2,-3,-2, 1, 2,-1, 5, 0,-2,-1,-1,-1,-1, 1,-3,-1,-1,-4 ],
						[-2,-3,-3,-3,-2,-3,-3,-3,-1, 0, 0,-3, 0, 6,-4,-2,-2, 1, 3,-1,-3,-3,-1,-4 ],
						[-1,-2,-2,-1,-3,-1,-1,-2,-2,-3,-3,-1,-2,-4, 7,-1,-1,-4,-3,-2,-2,-1,-2,-4 ],
						[ 1,-1, 1, 0,-1, 0, 0, 0,-1,-2,-2, 0,-1,-2,-1, 4, 1,-3,-2,-2, 0, 0, 0,-4 ],
						[ 0,-1, 0,-1,-1,-1,-1,-2,-2,-1,-1,-1,-1,-2,-1, 1, 5,-2,-2, 0,-1,-1, 0,-4 ],
						[-3,-3,-4,-4,-2,-2,-3,-2,-2,-3,-2,-3,-1, 1,-4,-3,-2,11, 2,-3,-4,-3,-2,-4 ],
						[-2,-2,-2,-3,-2,-1,-2,-3, 2,-1,-1,-2,-1, 3,-3,-2,-2, 2, 7,-1,-3,-2,-1,-4 ],
						[ 0,-3,-3,-3,-1,-2,-2,-3,-3, 3, 1,-2, 1,-1,-2,-2, 0,-3,-1, 4,-3,-2,-1,-4 ],
						[-2,-1, 3, 4,-3, 0, 1,-1, 0,-3,-4, 0,-3,-3,-2, 0,-1,-4,-3,-3, 4, 1,-1,-4 ],
						[-1, 0, 0, 1,-3, 3, 4,-2, 0,-3,-3, 1,-1,-3,-1, 0,-1,-3,-2,-2, 1, 4,-1,-4 ],
						[ 0,-1,-1,-1,-2,-1,-1,-1,-1,-1,-1,-1,-1,-1,-2, 0, 0,-2,-1,-1,-1,-1,-1,-4 ],
						[-4,-4,-4,-4,-4,-4,-4,-4,-4,-4,-4,-4,-4,-4,-4,-4,-4,-4,-4,-4,-4,-4,-4, 1 ],
						
						);
			
				my @aminoacids = ( 'A', 'R', 'N', 'D', 'C', 'Q', 'E', 'G', 'H', 'I', 'L', 'K', 'M', 'F', 'P', 'S', 'T', 'W', 'Y', 'V', 'B', 'Z', 'X', '*');
				
				my $create = sub {
					my $aa_lead    = 0 ;
						for my $line (@_) {
								for (my $a=0;$a<=$#{$line};$a++) {
										$SCORING{$aminoacids[$aa_lead].$aminoacids[$a]} = $line -> [$a];
								}
								$aa_lead ++
						}
				} ;
								
				$create -> ( @BLOSUM62 ) ;
				my $indel_score =  $SCORING{'A'.'*'};
				for (@aminoacids) { $SCORING{$_.'-'}  = $indel_score; $SCORING{'-'.$_}  = $indel_score; $SCORING{'-'.'-'} = $indel_score }
				
		return \%SCORING
}		
				


sub BLOSUM_dist {

		my ($taxon,$query,$ref_range,$ref_FASTA,$ref_scoring) = @_ ;
						
		# calculates distance according to the Scoredist approach of 
		# Sonnhammer and Hollich BMC Bioinformatics 2005, 6:108 doi:10.1186/1471-2105-6-108
		# distances are not calibrated like in Sonnhammer&Hollich 2005
							
		 my $overlap = @$ref_range ;
		 my $score = 0 ;
		 my $score_taxon = 0 ;
		 my $score_query = 0 ;		 
		 my $expected_score = 0 ;
		 my $BLOSUM_dist = 0;
		 
		 for (@$ref_range){
		 	 $overlap-- and next if (substr($ref_FASTA->{$taxon},$_,1)=~ /X|\-|\*/ or substr($ref_FASTA->{$query},$_,1)=~ /X|\-|\*/);
			 $score += $ref_scoring->{substr($ref_FASTA->{$taxon},$_,1).substr($ref_FASTA->{$query},$_,1)};	
			 $score_taxon += $ref_scoring->{substr($ref_FASTA->{$taxon},$_,1).substr($ref_FASTA->{$taxon},$_,1)};	
			 $score_query += $ref_scoring->{substr($ref_FASTA->{$query},$_,1).substr($ref_FASTA->{$query},$_,1)};	
		 }
		 
		 return $BLOSUM_dist = 1000 if $overlap < 20 ;
		 
		 $expected_score = -0.52 * $overlap ;
		 
		 return $BLOSUM_dist = 1000 if $score <= $expected_score ; 
		 
		 my $normalized_score = $score - $expected_score ;
		 my $normalized_upper_score = ($score_taxon + $score_query)/2 - $expected_score;
		 $BLOSUM_dist = -log($normalized_score/$normalized_upper_score) * 100 ; 
		 
		 # if overlap is less than 20 nucleotides or amino acids or even zero BLOSUM_dist will be set
		 # to 1000. This prevents a strong influence of only short overlaps between transcriptomes

		 return $BLOSUM_dist
}

sub compare {
	
	my $overlap = 0 ;
	my $identical = 0 ;
	my ($taxon, $query, $ref_range, $ref_FASTA) = @_ ;
	for (@$ref_range){
		next if (substr($ref_FASTA->{$taxon},$_,1)=~ /X|\-/ or substr($ref_FASTA->{$query},$_,1)=~ /X|\-/);
		$overlap++;	
		$identical++ if (substr($ref_FASTA->{$taxon},$_,1) eq substr($ref_FASTA->{$query},$_,1));
	}
	# if overlap is less than 50 nucleotides or amino acids it will be set
	# back to 0. This prevents a strong influence of only short overlaps 
	# between transcriptomes
	
	$overlap = 0 if $overlap < 50 ;
	return ($overlap, $identical)
}




sub indices {
	
	my ($taxon, $query, $ref_al_length, $ref_FASTA) = @_ ;
	$ref_FASTA->{$taxon} =~ /[^X\-]/;  
	my ($start)=@-;
	my $rev = reverse $ref_FASTA->{$taxon};
	$rev  =~ /[^X\-]/; 
	my ($end)=@+;
	return ($start, $$ref_al_length-$end),
}


sub read_FASTA {
	
	my %FASTA=();
	my $taxon=();
	my $al_length=();
	my $file =shift@_;
	
	open my $in,"<",$file;
	
	while (<$in>){
		chomp ;
		s/\|\|/\|/g;
		/^>(.+)/ ? ($taxon = $1) : ($FASTA{$taxon}.= uc($_)) ; 
	}
	
	$al_length=length $_ and last for values %FASTA;
		
	for my $sequences (values %FASTA){
		for (0..$al_length-1){
			substr($sequences,$_,1)=~/\-/ ? substr($sequences,$_,1,'X'): last 
		}
		for (0..$al_length-1){
			substr($sequences,$al_length-(1+$_),1)=~/\-/ ? substr($sequences,$al_length-(1+$_),1,'X'): last 
		}
	}print $al_length,"\n";
	return (\%FASTA, \$al_length)
}
