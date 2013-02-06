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

my %data_of = ();
my %overlap_of = ();
my %total_av_overlap_of = ();
my %total_av_identity_of = ();
my %total_avno_overlap_of = ();
my %total_avno_identity_of = ();
my %total_no_overlap_of = ();
my %total_no_identity_of = ();
my %total_overlap_of = ();
my %total_identity_of = ();
my %count_of_subject = ();
my %count_of_absentsubject = ();
my %count_of_singletons = ();
my $file_counter = 0;
my $taxon_presence = 1;

open my $subject_file,"<",'subjects.txt';
my @subject=<$subject_file>;
chomp @subject;
close $subject_file;

for (@subject){
	$data_of{"abs.$_"}=[];
	$data_of{"no.$_"}=[];
	$data_of{"av.$_"}=[];
	$data_of{"avno.$_"}=[];
	$data_of{"singletons.$_"}=[];
	$overlap_of{"no.$_"}=[];
	$overlap_of{"avno.$_"}=[];
	$overlap_of{"singletons.$_"}=[];
	$total_av_overlap_of{$_}=0;
	$total_av_identity_of{$_}=0;
	$total_avno_overlap_of{$_}=0;
	$total_avno_identity_of{$_}=0;
	$total_no_overlap_of{$_}=0;
	$total_no_identity_of{$_}=0;
	$total_overlap_of{$_}=0;
	$total_identity_of{$_}=0;
	$count_of_subject{$_}=0;
}

print "\n",'checking files',"\n";

while (<*.fas>){

	my %subject_local=();
	my @query_local=();
	$file_counter ++ ;
	my $file =$_;

	my ($ref_FASTA, $ref_al_length) = &read_FASTA($file);

	printf "\nfile: %-20.20s\talignment length: %-10.10s\n", $file,$$ref_al_length;
	printf "%-50.50s\t%-6.6s\t%-6.6s\t%-6.6s\n", 'taxon','ol','id','fit';

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
			printf "%-50.50s\t%-6.6s\t%-6.6s\t%-6.6s\n", $taxon,'0','0','0';
			push @{$data_of{"av.$taxon"}},'0';
			push @{$data_of{"abs.$taxon"}},'0';
			$count_of_absentsubject{$taxon}++;
			$taxon_presence = 0 ;
		}
	}

	for my $taxon(keys %subject_local){
		
		my ($overlap,$identical) = (0,0);
		my @taxon = split/\Q|\E/,$taxon;
					
		for my $query(@query_local){
			my ($o,$i)=&compare($taxon,$query,$ref_al_length,$ref_FASTA);
			$overlap += $o and $identical += $i
		}
		$overlap /= @query_local;
		$identical /= @query_local;
		$total_av_overlap_of{$taxon[2]} += $overlap;
		$total_av_identity_of{$taxon[2]} += $identical;
		printf "%-50.50s\t%-6.6s\t%-6.6s\t%-6.6s\n", "av.$taxon[2]",$overlap,$identical,$identical/$overlap;
		push @{$data_of{"av.$taxon[2]"}}, $identical/$overlap;
		
		if ($taxon_presence == 1){
			$total_avno_overlap_of{$taxon[2]} += $overlap;
			$total_avno_identity_of{$taxon[2]} += $identical;
			printf "%-50.50s\t%-6.6s\t%-6.6s\t%-6.6s\n", "avno.$taxon[2]",$overlap,$identical,$identical/$overlap;
			push @{$data_of{"avno.$taxon[2]"}}, $identical/$overlap;
			push @{$overlap_of{"avno.$taxon[2]"}}, $overlap;
		}
		else{
			printf "%-50.50s\t%-6.6s\t%-6.6s\t%-6.6s\n", "avno.$taxon[2]",'0','0','0';
			push @{$data_of{"singletons.$taxon[2]"}}, $identical/$overlap;
			push @{$overlap_of{"singletons.$taxon[2]"}}, $overlap;
			$count_of_singletons{$taxon[2]}++
		}
		
		($overlap,$identical) = &compare($taxon,$subject_local{$taxon},$ref_al_length,$ref_FASTA);
		$total_overlap_of{$taxon[2]} += $overlap;
		$total_identity_of{$taxon[2]} += $identical;
		printf "%-50.50s\t%-6.6s\t%-6.6s\t%-6.6s\n", $taxon[2],$overlap,$identical,$identical/$overlap;
		push @{$data_of{"abs.$taxon[2]"}}, $identical/$overlap;

		if ($taxon_presence == 1){
			$total_no_overlap_of{$taxon[2]} += $overlap;
			$total_no_identity_of{$taxon[2]} += $identical;
			printf "%-50.50s\t%-6.6s\t%-6.6s\t%-6.6s\n", "no.$taxon[2]",$overlap,$identical,$identical/$overlap;
			push @{$data_of{"no.$taxon[2]"}}, $identical/$overlap;
			push @{$overlap_of{"no.$taxon[2]"}}, $overlap;
		}
		else{
			printf "%-50.50s\t%-6.6s\t%-6.6s\t%-6.6s\n", "no.$taxon[2]",'0','0','0';
		}
				
		$count_of_subject{$taxon[2]}++;
		
	}
	$taxon_presence = 1 ;
}


print<<STAT;

total number of files checked: $file_counter

STAT

printf "%-50.50s\t%-10.10s\n",'taxon','absent';
print  "--------------------------------------------------------------------------------------------------\n";
printf "%-50.50s\t%-10.10s\n", $_,$count_of_absentsubject{$_} for keys %count_of_absentsubject ;

printf "\n%-50.50s\t%-10.10s\n",'taxon','singletons';
print  "--------------------------------------------------------------------------------------------------\n";
printf "%-50.50s\t%-10.10s\n", $_,$count_of_singletons{$_} for keys %count_of_singletons ;

print  "\ntotal overlap, identity and fit:\n"; 
printf "%-50.50s\t%-6.6s\t%-6.6s\t%-6.6s\n",'taxon','ol','id','fit';
print  "--------------------------------------------------------------------------------------------------\n";

for (keys %total_overlap_of){
	my $fit;
	($total_overlap_of{$_} == 0) ? ($fit=0) : ($fit=$total_identity_of{$_}/$total_overlap_of{$_}) ;
	printf "%-50.50s\t%-6.6s\t%-6.6s\t%-6.6s\n", $_,$total_overlap_of{$_},$total_identity_of{$_},$fit;
	($total_no_overlap_of{$_} == 0) ? ($fit=0) : ($fit=$total_no_identity_of{$_}/$total_no_overlap_of{$_}) ;
	printf "%-50.50s\t%-6.6s\t%-6.6s\t%-6.6s\n", "no.$_",$total_no_overlap_of{$_},$total_no_identity_of{$_},$fit;
	($total_av_overlap_of{$_} == 0) ? ($fit=0) : ($fit=$total_av_identity_of{$_}/$total_av_overlap_of{$_}) ;
	printf "%-50.50s\t%-6.6s\t%-6.6s\t%-6.6s\n", "av.$_",$total_av_overlap_of{$_},$total_av_identity_of{$_},$fit;
	($total_avno_overlap_of{$_} == 0) ? ($fit=0) : ($fit=$total_avno_identity_of{$_}/$total_avno_overlap_of{$_}) ;
	printf "%-50.50s\t%-6.6s\t%-6.6s\t%-6.6s\n", "avno.$_",$total_avno_overlap_of{$_},$total_avno_identity_of{$_},$fit;
	
}


&boxplot_svg(\%data_of,'normalized');
&boxplot_svg(\%overlap_of,'overlap');


#_____________________________________________________________________________________________________________________________________


sub boxplot_svg {

	my $ref_hash=shift@_;
	my $file=shift@_;
	my $maximum=0;
	my $number_of_data=keys %$ref_hash; 
	for (keys %$ref_hash){
		if (@{$ref_hash->{$_}}>0){
			my @sorted=sort{$a<=>$b}@{$ref_hash->{$_}};
			$maximum = $maximum < $sorted[-1] ? $sorted[-1] : $maximum
		} 
	}
	open my $boxplot , ">" , "${file}.svg"                                   ;

	my $init_line = '<?xml version="1.0" encoding="UTF-8" standalone="no"?>' ;
	my $gen_line  = '<!-- created by matrix_reduction.pl -->'                ;
	my $width  = 1000  ;
	my $height =  1000 ;
	my $unit_height= $maximum <= 1 ? 1000/($maximum*10) : 1000/$maximum;
	my $unit_width=1000/$number_of_data;
	my $framewidth = $width+$unit_width;
	my $frameheight= $height+$unit_height;
	my $baseline= $maximum <= 1 ? $frameheight*1.05 : $frameheight*1.05;

print $boxplot <<FRAME1;
$init_line
$gen_line

<svg
   xmlns:svg="http://www.w3.org/2000/svg"
   xmlns="http://www.w3.org/2000/svg"
   version="1.0"
   width="$framewidth"
   height="$frameheight"
   id="svg2">

  <defs
     id="defs4" />

<line
     x1="0"
     y1="0"
     x2="0"
     y2="$frameheight"
     style="stroke: black;stroke-width:1;stroke-linecap:round;stroke-linejoin:round"
     id="line001" />

<line
     x1="0"
     y1="$baseline"
     x2="$framewidth"
     y2="$baseline"
     style="stroke: black;stroke-width:1;stroke-linecap:round;stroke-linejoin:round"
     id="line002" />

FRAME1


	if ($maximum <=1){
		for (0..($maximum)*10){
			print {$boxplot}   '<line',"\n",'x1="0" y1="',$frameheight-$unit_height*$_,'" x2="-5" y2="',$frameheight-$unit_height*$_,'" style="stroke: black;stroke-width:1;stroke-linecap:round;stroke-linejoin:round" id="line004"/>',"\n";
			print {$boxplot}   '<text',"\n",'x="-15" y="',$frameheight-$unit_height*$_,'"',' text-anchor="end"',"\n",'style="font-size:12px;font-family:Bitstream Vera Sans"',"\n",'>',$_/10,'</text>',"\n"
		}
	}
	elsif($maximum >1 and $maximum <= 10){
		for (my $i=0;$i<=$maximum;$i++){
			print {$boxplot}   '<line',"\n",'x1="0" y1="',$frameheight-$unit_height*$i,'" x2="-5" y2="',$frameheight-$unit_height*$i,'" style="stroke: black;stroke-width:1;stroke-linecap:round;stroke-linejoin:round" id="line004"/>',"\n";
			print {$boxplot}   '<text',"\n",'x="-15" y="',$frameheight-$unit_height*$i,'"',' text-anchor="end"',"\n",'style="font-size:12px;font-family:Bitstream Vera Sans"',"\n",'>',$i,'</text>',"\n"
		}
	}
	elsif($maximum >10 and $maximum <= 100){
		for (my $i=0;$i<=$maximum;$i+=10){
			print {$boxplot}   '<line',"\n",'x1="0" y1="',$frameheight-$unit_height*$i,'" x2="-5" y2="',$frameheight-$unit_height*$i,'" style="stroke: black;stroke-width:1;stroke-linecap:round;stroke-linejoin:round" id="line004"/>',"\n";
			print {$boxplot}   '<text',"\n",'x="-15" y="',$frameheight-$unit_height*$i,'"',' text-anchor="end"',"\n",'style="font-size:12px;font-family:Bitstream Vera Sans"',"\n",'>',$i,'</text>',"\n"
		}
	}
	else{
		for (my $i=0;$i<=$maximum;$i+=100){
			print {$boxplot}   '<line',"\n",'x1="0" y1="',$frameheight-$unit_height*$i,'" x2="-5" y2="',$frameheight-$unit_height*$i,'" style="stroke: black;stroke-width:1;stroke-linecap:round;stroke-linejoin:round" id="line004"/>',"\n";
			print {$boxplot}   '<text',"\n",'x="-15" y="',$frameheight-$unit_height*$i,'"',' text-anchor="end"',"\n",'style="font-size:12px;font-family:Bitstream Vera Sans"',"\n",'>',$i,'</text>',"\n"
		}
	}
		
		
	for (0..$number_of_data){
		print {$boxplot}  '<line',"\n",'x1="',$unit_width*$_,'" y1="',$baseline,'" x2="',$unit_width*$_,'" y2="',$baseline+5,'" style="stroke: black;stroke-width:1;stroke-linecap:round;stroke-linejoin:round" id="line004"/>',"\n"
	}

	my $min=0;
	my $max=0;
	my $median=0;
	my $Q1=0;
	my $Q3=0;
	my $W1=0; 
	my $W3=0; 
	my $counter=0;

print  "\n$file.stats:\n";
printf "%-50.50s\t%-6.6s\t%-6.6s\t%-6.6s\t%-6.6s\t%-6.6s\n",'taxon','min','max','median','Q1','Q3';
print  "--------------------------------------------------------------------------------------------------\n";


	my @keys= sort keys %$ref_hash ;
	
	for (@keys){
		next if @{$ref_hash->{$_}} < 4 ;
		my $colour = /singleton/ ? '#ffe680' : 'lightgrey' ;
		my @sorted_input=sort{$a<=>$b}@{$ref_hash->{$_}};
		$counter++;
		$max=$sorted_input[-1];
		$min=$sorted_input[0];
		$median = &median(\@sorted_input);
		if (@sorted_input%2 ==1){
			$Q1=&median([@sorted_input[0..((@sorted_input+1)/2)-2]]);
			$Q3=&median([@sorted_input[((@sorted_input+1)/2)..$#sorted_input]])
		}
		else{
			$Q1=&median([@sorted_input[0..((@sorted_input+1)/2)-1]]);
			$Q3=&median([@sorted_input[((@sorted_input+1)/2)..$#sorted_input]])
		}
		$W1= $median-1.5*($median-$Q1) < 0 ? 0 : $median-1.5*($median-$Q1);
		$W3= $median+1.5*($Q3-$median) > $maximum ? $maximum : $median+1.5*($Q3-$median);

		printf "%-50.50s\t%-6.6s\t%-6.6s\t%-6.6s\t%-6.6s\t%-6.6s\n",$_,$min,$max,$median,$Q1,$Q3;
		
		$unit_height = $maximum <=1 ? $unit_height*10 : $unit_height ;  
		
		for (@sorted_input){
			if ($_<$W1){
				print {$boxplot} '<circle',"\n",'cx="',$unit_width*$counter,'" cy="',$frameheight-$_*$unit_height,'" r="4" stroke="black" strake-width="0.3" fill="none" />',"\n"
			}
			else{
				last
			}
		}
		for (@sorted_input){
			if ($_<=$W3){
				next
			}
			else{
				print {$boxplot} '<circle',"\n",'cx="',$unit_width*$counter,'" cy="',$frameheight-$_*$unit_height,'" r="4" stroke="black" strake-width="0.3" fill="none" />',"\n"
			}
		}
		print {$boxplot}  '<line',"\n",'x1="',$unit_width*$counter-$unit_width/4,'" y1="',$frameheight-$W1*$unit_height,'" x2="',$unit_width*$counter+$unit_width/4,'" y2="',$frameheight-$W1*$unit_height,'" style="stroke: black;stroke-width:1;stroke-linecap:round;stroke-linejoin:round" id="W1"/>',"\n";
		print {$boxplot}  '<line',"\n",'x1="',$unit_width*$counter-$unit_width/4,'" y1="',$frameheight-$W3*$unit_height,'" x2="',$unit_width*$counter+$unit_width/4,'" y2="',$frameheight-$W3*$unit_height,'" style="stroke: black;stroke-width:1;stroke-linecap:round;stroke-linejoin:round" id="W3"/>',"\n";
		print {$boxplot}  '<line',"\n",'x1="',$unit_width*$counter,'" y1="',$frameheight-$W1*$unit_height,'" x2="',$unit_width*$counter,'" y2="',$frameheight-$Q1*$unit_height,'" style="stroke: black;stroke-width:1;stroke-linecap:round;stroke-linejoin:round" id="lineQ1"/>',"\n";
		print {$boxplot}  '<line',"\n",'x1="',$unit_width*$counter,'" y1="',$frameheight-$W3*$unit_height,'" x2="',$unit_width*$counter,'" y2="',$frameheight-$Q3*$unit_height,'" style="stroke: black;stroke-width:1;stroke-linecap:round;stroke-linejoin:round" id="lineQ3"/>',"\n";
	    print {$boxplot}  '<path',"\n",'d="M',$unit_width*$counter-$unit_width/4,' ',$frameheight-$Q1*$unit_height,' L',$unit_width*$counter+$unit_width/4,' ',$frameheight-$Q1*$unit_height,' L',$unit_width*$counter+$unit_width/4,' ',$frameheight-$Q3*$unit_height,' L',$unit_width*$counter-$unit_width/4,' ',$frameheight-$Q3*$unit_height,' Z" style="stroke:black;stroke-width:1;fill:',$colour,';" />',"\n";
		print {$boxplot}  '<line',"\n",'x1="',$unit_width*$counter-$unit_width/3.8,'" y1="',$frameheight-$median*$unit_height,'" x2="',$unit_width*$counter+$unit_width/3.8,'" y2="',$frameheight-$median*$unit_height,'" style="stroke: black;stroke-width:3;stroke-linecap:round;stroke-linejoin:round" id="median"/>',"\n";
		
		$unit_height = $maximum <=1 ? $unit_height/10 : $unit_height ;	
			
	}
	
	$counter=0;	
	
	for (@keys){  
		$counter++;
		print {$boxplot} '<text x="',$unit_width*$counter,'" y="',$baseline+20,'"',"\n",'transform="rotate(90,',$unit_width*$counter,',',$baseline+20,')"',"\n",'style="font-size:12px;font-family:Bitstream Vera Sans"',"\n",'>',$_,'</text>',"\n"
	} 

print $boxplot <<FINISH;

</svg>


FINISH

print "\nboxplots done\n\n"

}

sub median {
	my ($p)=@_;
	my $median = @$p%2 ==1 ? $$p[((@$p+1)/2)-1] : ($$p[(@$p/2)-1]+$$p[@$p/2])/2;
	return $median
}
	


sub compare {
	
	my $overlap = 0 ;
	my $identical = 0 ;
	my ($taxon, $query, $ref_al_length, $ref_FASTA) = @_ ;
	
	for (0..$$ref_al_length-1){
		(substr($ref_FASTA->{$taxon},$_,1)=~ /X|\-/) ? next : $overlap++;
		(substr($ref_FASTA->{$taxon},$_,1) ne substr($ref_FASTA->{$query},$_,1)) ? next : $identical++;
	}
	return ($overlap, $identical)
}



sub read_FASTA {
	
	my %FASTA=();
	my $taxon=();
	my $al_length=();
	my $file =shift@_;
	
	open my $in,"<",$file;
	
	while (<$in>){
		chomp ;
		/^>(.+)/ ? ($taxon = $1) : ($FASTA{$taxon}.= $_) ; 
	}
	
	$al_length=length $_ and last for values %FASTA;
		
	for my $sequences (values %FASTA){
		for (0..$al_length-1){
			substr($sequences,$_,1)=~/\-/ ? substr($sequences,$_,1,'X'): last 
		}
		for (0..$al_length-1){
			substr($sequences,$al_length-(1+$_),1)=~/\-/ ? substr($sequences,$al_length-(1+$_),1,'X'): last 
		}
	}
	return (\%FASTA, \$al_length)
}
