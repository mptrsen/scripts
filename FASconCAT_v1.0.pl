#!/usr/bin/perl
use strict;
use File::Copy;
use Tie::File;
use Term::ANSIColor qw(:constants);
use Getopt::Std;

# written by patrick kück, zentrales forschungsmuseum alexander koenig, bonn, germany
# email: patrick_kueck@web.de

# updated on 12th,january      , 2009 by patrick kueck
# updated on 25th may            , 2009 by patrick kueck
# updated on 28th may            , 2009 by patrick kueck
# updated on 7th june           , 2009 by patrick kueck
# updated on 8th june           , 2009 by patrick kueck
# updated on 28th september , 2009 by patrick kueck
# updated on 16th october      , 2009 by patrick kueck
# updated on 17th november    , 2009 by patrick kueck
# updated on 7th january       , 2010 by patrick kueck
# updated on 7th april            , 2010 by patrick kueck
# updated on 8th april            , 2010 by patrick kueck

####################################################### START #######################################################################################

my $out_fas                 =     "FcC_smatrix.fas"             ;
my $out_info                =     "FcC_info.xls"                ;

my @parameter_all           =   ( "YES" , "NO"                ) ;
my @parameter_info          =   ( "NO"  , "YES"               ) ;
my @parameter_phy           =   ( "NO"  , "STRICT", "RELAXED" ) ;
my @parameter_nex           =   ( "NO"  , "BLOCK" , "MrBAYES" ) ;

my %files                   = ()  ; my $href_files              = \%files              ; # keys: filename within same folder or predefined filenames ; values: counternumber
my %filelist                = ()  ; my $href_filelist           = \%filelist           ; # keys: filenumber ; values: filenames within same folder as fasconcat
my %struc_of_file           = ()  ; my $href_struc_of_file      = \%struc_of_file      ; # keys: filename ; value: structurestring
my %namen                   = ()  ; my $href_namen              = \%namen              ; # keys: taxonnames ; values : counter
my %input                   = ()  ; my $href_input              = \%input              ; # keys: filename ; values: filecontent
my %struc_of_tax            = ()  ; my $href_struc_of_tax       = \%struc_of_tax       ; # keys: sequencename; value: counter
my %file_startpoint         = ()  ; my $href_file_startpoint    = \%file_startpoint    ; # keys: filename; value: startpoints within supermatrix
my %file_endpoint           = ()  ; my $href_file_endpoint      = \%file_endpoint      ; # keys: filename; value: endpoints within supermatrix
my %sequence_all            = ()  ;                                                      # keys: taxa; values: concatenated sequence of each taxa
my %info_simple             = ()  ;
my %file_struc_pairs        = ()  ; my $href_file_struc_pairs   = \%file_struc_pairs   ; # key: filename; value : pairings, comma separated
my %file_struc_stems        = ()  ; my $href_file_struc_stems   = \%file_struc_stems   ; # key: filename; value: pairings, whitespave seperated
my %file_struc_loops        = ()  ; my $href_file_struc_loops   = \%file_struc_loops   ; # key: filename ; value : looppositions
my %concat_taxcheck         = ()  ;                                                      # key: taxon ; values: number of concatenations in total 
my %N_loops                 = ()  ; my $href_N_loops            = \%N_loops            ; # key: filename; values: number of loopcharacters
my %N_stems                 = ()  ; my $href_N_stems            = \%N_stems            ; # key: filename; values: number of stem characters
my %P_loops                 = ()  ; my $href_P_loops            = \%P_loops            ; # key: filename; values: percent of loopcharacters
my %P_stems                 = ()  ; my $href_P_stems            = \%P_stems            ; # key: filename; values: percent of stem characters
my %N_total                 = ()  ; my $href_N_total            = \%N_total            ; # key: filename; values: number of total structure characters
my %seq_type                = ()  ; my $href_seq_type           = \%seq_type           ; # key: filename; values: aminoacid or nucleotide
my %single_infos_of_file    = ()  ;                                                      # key: filename; values:
my %number_merkmale         = ()  ; my $href_number_merkmale    = \%number_merkmale    ; # key: filename; values: Number of filecharacters
my %counter_total           = ()  ;
my %counter_gaps            = ()  ; my $href_counter_gaps       = \%counter_gaps       ; # key: filename; values: gapnumber
my %counter_ambs            = ()  ; my $href_counter_ambs       = \%counter_ambs       ; # key: filename; values: ambiguity number
my %counter_misdata         = ()  ; my $href_counter_misdata    = \%counter_misdata    ; # key: filename; values: number of missing data (?)
my %counter_N_inserted      = ()  ; my $href_counter_N_inserted = \%counter_N_inserted ; # key: filename ; value: number of missing characters included
my %Ntax_of_file            = ()  ; my $href_Ntax_of_file       = \%Ntax_of_file       ; # key: filename ; value: taxonnumber
my %N_conc_taxon            = ()  ;                                                      # key: taxonname ; value: number of concatinations -> for taxon check
my %N_characters            = ()  ; my $href_N_characters       = \%N_characters       ; # key: filename ; value : number of filecharacters
my %taxon_aa                = ()  ;                                                      # key: taxon with aminoacid sequences; value: counternumber
my %struc_tax_of_file       = ()  ;                                                      # key: filename , value: structuresequence associated taxon
my %struc_tax               = ()  ;                                                      # key: reference ; value: first structuresequence associated taxon
my %counter_tax_inserted    = ()  ; my $href_counter_tax_inserted = \%counter_tax_inserted ;

START:
&argv_handling ; &menu ; &parameter ;


################################################################## END ###############################################################################

sub argv_handling{
	
	
	my ( $commandline ) = join "", @ARGV ;
	
	if ( $commandline ne undef ){ 
		
		$commandline =~ s/ |\s+// ;
		my @commands = split "-", $commandline ;
		
		REPEAT_ARGV:
		for my $single_command ( sort @commands ){
			
			$single_command =~ /^help$/i and do { &help } ;
			$single_command =~ /^i$/i    and do { @parameter_info = ( reverse @parameter_info ) ; next REPEAT_ARGV } ;
			$single_command =~ /^f$/i    and do { @parameter_all  = ( reverse @parameter_all  ) ; next REPEAT_ARGV } ;
			$single_command =~ /^p$/i    and do { my $tl = shift @parameter_phy ; push @parameter_phy, $tl ; next REPEAT_ARGV } ;
			$single_command =~ /^n$/i    and do { my $tl = shift @parameter_nex ; push @parameter_nex, $tl ; next REPEAT_ARGV } ;
			$single_command =~ /^s$/i    and do { &start } ;
		}
	}
}

sub menu{ system('cls');
	
	print "";
	printf "\n%68s\n","------------------------------------------------------------"  ;
	printf "%53s\n"  , "Welcome to FASconCAT v1.0 !"                                  ;
	printf "%58s\n"  , "A perlscript for sequence concatenation"                      ;
	printf "%59s\n"  , "written by Patrick Kueck (ZFMK Bonn, 2010)"                   ;
	printf "%68s\n\n", "------------------------------------------------------------" ;
}

sub parameter{
	PARAMETER:
	print "";
	print  "\n\tSTART\tFASconCAT     :\t\t\t type <s> <enter>  "                      ;
	print  "\n\n\tINPUT   ALL/SINGLE    :\t\t\t type <f> <enter>  "                   ;
	print  "\n\tINFO\tALL/SMALL     :\t\t\t type <i> <enter>  "                       ;
	print  "\n\n\tNEXUS   BLOCK/MrBAYES :\t\t\t type <n> <enter>  "                   ;
	print  "\n\tPHYLIP  NO/YES        :\t\t\t type <p> <enter>  "                     ;
	print  "\n\n\tHELP    FASconCAT     :\t\t\t type <h> <enter>"                     ;
	print  "\n\tQUIT    FASconCAT     :\t\t\t type <q> <enter>  "                     ;
	print  "\n\tPREFACE FASconCAT     :\t\t\t type <a> <enter>\n"                     ;
	print  "\n\t------------------------------------------------------------"         ;
	print  "\n\n\tFASTA/PHYLIP-INPUT"                                                 ;
	print  "\n\t-----------------"                                                    ;
	print  "\n\tConcatenate    ALL files  :\t$parameter_all[0]"                       ;
	print  "\n\tConcatenate SINGLE files  :\t$parameter_all[1]\n  "                   ;
	print  "\n\tOUTPUT"                                                               ;	
	print  "\n\t------"                                                               ;
	print  "\n\tSupermatrix + ALL info    :\t$parameter_info[0]"                      ;
	print  "\n\tSupermatrix               :\t$parameter_info[1]"                      ;
	print  "\n\n\tNEXUS-Block               :\t$parameter_nex[0]"                     ;
	print  "\n\tPHYLIP                    :\t$parameter_phy[0]\n\n"                   ;
	print  "\n\t------------------------------------------------------------\n"       ;
	
	my       $answer_opening =  &commandline ;
	until  ( $answer_opening =~ /^s$|^i$|^f$|^q$|^h$|^n$|^p$|^a$/i ){ 
		
		my @errorreport = "\n\t!COMMAND-ERROR!: unknown command \"$answer_opening\"!\n" ;
		#print "\n\t!COMMAND-ERROR!: unknown command \"$answer_opening\"!\n" ;
		$answer_opening =  &commandline(@errorreport) ;
	}

	$answer_opening =~ /^s$/i and do { &start } ;
	$answer_opening =~ /^f$/i and do { @parameter_all  = ( reverse @parameter_all  ) ;            &menu; &parameter } ;
	$answer_opening =~ /^i$/i and do { @parameter_info = ( reverse @parameter_info ) ;            &menu; &parameter } ;
	$answer_opening =~ /^p$/i and do { my $tl = shift @parameter_phy ; push @parameter_phy, $tl ; &menu; &parameter } ;
	$answer_opening =~ /^n$/i and do { my $tl = shift @parameter_nex ; push @parameter_nex, $tl ; &menu; &parameter } ;
	$answer_opening =~ /^q$/i and do { exit } ;
	$answer_opening =~ /^h$/i and do { &help } ;
	$answer_opening =~ /^a$/i and do { &preface }
}

sub help{ 


	system('cls');

	
print 
<<help
	
	--------------------FASconCAT HELP-MENU---------------------
	
	'Features'
	-----------
	FASconCAT extracts taxon specific associated gene- 
	or structure sequences out of given FASTA, PHYLIP or 
	CLUSTAL files and joins them together 'end to end' 
	to one string. Missing taxon sequences in single 
	files are replaced either by 'N', 'X' or by '.' 
	(dots), dependend on their taxon associated sequence 
	kinds in other input files. 
	Beside the mean concatenation process, FASconCAT 
	delivers additional information about each input 
	file and the new concatenated supermatrix.
	The extent of information depends on the choosen info
	setting. Further, FASconCAT can generate NEXUS files
	of concatenated sequences, either with or without 
	MrBayes commands.
	FASconCAT can be started directly in one single 
	command line or via menu options.
	
	
	'Default Settings'
	------------------
	Under default, FASconCAT checks all FASTA, CLUSTAL and
	PHYLIP files of the user defined input folder and 
	concatenates all correct formatted files to a super-
	matrix in FASTA format. Additionally it provides 
	range information within the supermatrix as well 
	as a check list of concatenated sequences. 

	
	'All Infos'
	-----------
	It is possible to choose the 'All Infos' setting which
	is slightly slower than the default setting. It gives
	additional information about:

	>For each single input file and the new supermatrix: 
	- Number of taxa
	- Number of sequence characters
	- Sequence type, either 'Nucleotide' or 'Amino acid' 
	- Number of single nucleotide characters, gaps and ambiguities
	- Number of inserted replacement characters
	- Number of inserted replacement strings

	>For the new supermatrix:
	- Number of all characters within the matrix
	- Percent and number of all nucleotides, gaps and ambiguities
	- Percent and number of all inserted replacement characters

	>For each single, structure comprising file and the new 
	supermatrix:
	- Filename
	- Total number of structure characters seperated in loops 
	  and stems 
	- Number and percent of loop and stem positions per fragment
	- Separated list (FcC_structure.txt) for loop positions and 
	stem pairings whitin the supermatrix

	
	'Concatenated Files'
	--------------------
	FASconCAT considers either all files within
	the input folder or user defined selection. If 
	the 'defined' option is chosen, a new list-window
	opens in which input files can be defined.

	
	'Output Files'
	--------------
	>FASconCAT dispenses 2 files per default:
	- A concatenated supermatrix file 'FcC_smatrix.fas'
	- A sequence information file 'FcC_info.xls'
	
	>Additionally with specified options:
	- A NEXUS STANDARD/MrBAYES file 'FcC_smatrix.nex'
	- A PHYLIP file 'FcC_smatrix.phy'
	- Structure information 'FcC_smatrix_structure.txt'
    
	
	'Start FASconCAT'
	-----------------
	To start FASconCAT under default, open the script by 
	double klick (Windows) or via the terminal.
	
	>Via menu options:
	- perl FASconCAT_v1.0.pl <enter> (Linux/Mac)
	- FASconCAT_v1.0.pl <enter> (Windows)
	
	>Via command line type: 
	- perl FASconCAT_v1.0.pl [command options] <enter> 
	  (Linux/Mac)
	- FASconCAT_v1.0.pl [command options] <enter> 
	  (Windows)
	  
	Command options:
	  -i ALL available information
	  -p PHYLIP output (strict taxon names)
	  -p -p PHYLIP output (relaxed taxon names)
	  -f DEFINED concatenation
	  -n NEXUS output
	  -n -n NEXUS output + MrBayes commands
	  -s START
	
	For further detailed information please consult 
	the manual or write an email to fasconcat\@web.de
	------------------------------------------------------------
	
help
; 

	print  "\tBACK to FASconCAT MAIN-Menu:\t\t type <return>\n"                    ;
	print  "\n\t------------------------------------------------------------\n\t"  ;

	chomp ( my $answer_xy = <STDIN> );

	&menu; &parameter ; 
}

sub preface{

	system('cls');

	
print
<<preface
	
	--------------------FASconCAT PREFACE---------------------
	
	Version     : 1.0
	Language    : PERL
	Last Update : 11th Nobember, 2009
	Author      : Patrick Kück, ZFMK Bonn, GERMANY
	e-mail      : fasconcat\@web.de
	Homepage    : http://fasconcat.zfmk.de
	
	This program is free software; you can distribute it 
	and/or modify it under the terms of the GNU General Public 
	License as published by the Free Software Foundation ; 
	either version 2 of the License, or (at your option) any 
	later version.

	This program is distributed in the hope that it will be 
	useful, but WITHOUT ANY WARRANTY; without even the 
	implied warranty of MERCHANTABILITY or FITNESS FOR A 
	PARTICULAR PURPOSE. See the GNU General Public License for 
	more details. 

	You should have received a copy of the GNU General Public 
	License along with this program; if not, write to the Free 
	Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, 
	USA.
	
	For further free downloadable programs visit:
	http://software.zfmk.de
	
	------------------------------------------------------------

preface
; 

	print  "\tBACK to FASconCAT MAIN-Menu:\t\t type <return>\n"                    ;
	print  "\n\t------------------------------------------------------------\n\t"  ;

	chomp ( my $answer_xy = <STDIN> );

	&menu; &parameter ; 
}

sub start{
	
	&menu ;
	
	print "\n\n\t#### FASconCAT: START ! ####" ;
	print "\n\t------------------------------------------------------------\n\n" ;
	
	if ( $parameter_nex[0]  =~ /BLOCK|MrBAYES/ ){ $parameter_info[0] = "YES" }
	
	my $counter_files = 0 ;
	
	for my $format ( qw/aln phy FASTA fas/ ){
		
		for my $file_input ( <*.$format> ){ $counter_files++ ; $files{$file_input}++ ; $filelist{$counter_files} = $file_input }
	}
	
	if ( $parameter_all[0]  =~ "YES" ){ &input_check } else { &single_define } &concatenate ;
	if ( $parameter_info[0] =~ "YES" ){ if ( defined keys %struc_of_file ){ &structure_handling ; &get_info } else { &get_info } }
	
	&print_out ; &end ;
	
	sub single_define{
		
		for ( sort {$a<=>$b} keys %$href_filelist ){ print "\n\t$_\t$filelist{$_}" }
		
		my      @errorreport  =  "\n\tNumber of INPUT files comma separated ( BACK <b> ): " ;
		my      $number_input =  () ;
		until ( $number_input =~ /^\d+(,\d+)*$|^b$|^B$/i ){ $number_input = &commandline(@errorreport) }
		
		$number_input         =~ /^b$/i and do { &menu; &parameter };
		
		my @file_numbers      =  split ",", $number_input ;
		
		%files = () ;
		for( @file_numbers ){ $files{ $filelist{$_} }++ } ; 
		
		&input_check ;
	}
	
	sub input_check{
		
		for my $file ( sort {$a<=>$b} keys %$href_files ){
			
			open IN, $file or die "\n\t!FILE-ERROR!: $file can't be read in !" ;
			
			if ( $file =~ /^.*\.aln$/             ){ push my @aln_files_all, $file ; &aln2fas ( @aln_files_all) }
			if ( $file =~ /^.*\.phy$/             ){ push my @phy_files_all, $file ; &phy2fas ( @phy_files_all) }
			if ( $file =~ /^.*\.fas$|^.*\.FASTA$/ ){ push my @fas_files_all, $file ; &fasEDIT ( @fas_files_all) }
			
			my @file_input = exists($input{$file}) ? @{$input{$file}} :( ) ;
			
			die "\n\t!FILE-ERROR!: Unknown input format of $file !\n" if 0 == @file_input ;
			
			my $N_elem_input        = @file_input           ;
			my %raw_sequence        = @file_input           ;
			my $N_elem_keys         = keys %raw_sequence    ;
			my $laenge_sequence     = length $file_input[1] ;
			my @taxon_structure_raw = ( )                   ;
			my %seen_taxon_raw      = ( )                   ;
			
			unless ( $N_elem_keys  == $N_elem_input / 2 ){ die "\n\t!FILE-ERROR!: Multiple sequence names in $file!\n" }
			
			READING:
			for my $raw_taxon ( sort keys %raw_sequence ){
				
				die    "\n\t!FILE-ERROR!: $raw_taxon in $file is not in FASTA format!\n"                     if           $raw_taxon                  !~ /^\>/            ;
				die    "\n\t!FILE-ERROR!: Sequence name missing in $file!\n"                                 if           $raw_taxon                  =~ /^\>$/           ;
				die    "\n\t!FILE-ERROR!: Sequence name $raw_taxon in $file involves forbidden signs!\n"     if           $raw_taxon                  !~ /\w/             ;
				die    "\n\t!FILE-ERROR!: Sequences of $file have no equal length!\n"                        if length    $raw_sequence{$raw_taxon}   != $laenge_sequence ;
				die    "\n\t!FILE-ERROR!: Sequence missing in $file!\n"                                      if           $raw_sequence{$raw_taxon}   =~ /^\n$|^$/        ;
				
				if ( $raw_sequence{$raw_taxon} =~ /.*\(.*\).*/ ){
					
					$raw_sequence{$raw_taxon}  =~ s/-/./g  ;
					my @strc_elements          =  split "" , $raw_sequence{$raw_taxon} ;
					
					for my $str_sign ( @strc_elements ){ 
						
						unless ( $str_sign =~ /\(|\)|\./ ){ die "\n\t!FILE-ERROR!: Sequence of $file involves forbidden signs in $raw_taxon!\n" }
					}
					
					unless ( defined $struc_of_file{$file} ){
						
						if ( defined $struc_tax{reference} && ( $raw_taxon ne $struc_tax{reference} ) ){ die "\n\t!FILE-ERROR!: Additional structure sequence of sequence $raw_taxon in $file not allowed!\n"}
						
						$struc_of_file{$file}      =  $raw_sequence{$raw_taxon}                        ;
						$struc_of_tax{$raw_taxon}  =  $raw_sequence{$raw_taxon}                        ;
						$struc_tax_of_file{$file}  =  $raw_taxon                                       ;
						$struc_tax{reference}      =  $raw_taxon                                       ;
						$namen{$raw_taxon}++       ;
						
						print  "\n\t!FILE-INFO!: $file involves structure sequence\n\tin $raw_taxon\n" ; next READING 
					}
					else{ die "\n\t!FILE-ERROR!: $file involves multiple structure sequences\n" }
				}
				
				$raw_sequence{$raw_taxon}  =~ s/(\w+)/\U$1/ig ;
				my @seq_elements           = split "" , $raw_sequence{$raw_taxon} ;
				
				for my $seq_sign ( @seq_elements ){ 
					
					unless ( $seq_sign =~ /A|C|G|T|U|-|N|Y|X|R|W|S|K|M|D|V|H|B|Q|E|I|L|F|P|\?/ ){ die "\n\t!FILE-ERROR!: Sequence of $file involves forbidden signs in $raw_taxon!\n" }
				}
				
				if ( $raw_sequence{$raw_taxon}  =~ /I|E|L|Q|F|P/ ) { $taxon_aa{$raw_taxon}++ } $namen{$raw_taxon}++ ;
			}
		}
		
		sub aln2fas{
			
			my @aln_file = @_ ; &tie_linefeeds( @aln_file ) ;
			
			my (@tax_seq_split, @taxa, $clustal, %sequenzen_alle) = ();
			
			my $file_aln = $aln_file[0] ;
			
			#%sequenzen_alle  = () ;
			my @inputfile    = () ;
			
			open INaln, $file_aln or die "\n\t$file_aln can not be found!\n" ;
			
			while (my $line = <INaln>){
				
				chomp  $line ;
				if   ( $line =~ /^CLUSTAL/i ){ $clustal=1 }
				push   @inputfile, "$line\n" ;
			}  
			close INaln;
			
			if ($clustal == 1) { splice (@inputfile, 0, 2) } else { die "$file_aln is not a CLUSTAL format!\n" }
			
			for (@inputfile){ if ( /^\W/ ) { s/.*/:/g ; s/\n// } }
			
			my $string_inputfile =  join  ""  , @inputfile        ;
			   $string_inputfile =~ s/:+/:/g  , $string_inputfile ;
			my @seq_parts        =  split ":" , $string_inputfile ;
			
			for ( @seq_parts ){ 
				
				my @tax_seq = split "\n", $_ ;
				
				for ( @tax_seq ){ s/ +/:/ ; push @tax_seq_split, (split ":", $_) }
				
				my %sequenzen  = @tax_seq_split  ;
				@tax_seq_split = ()              ;
				@taxa          = keys %sequenzen ;
				
				for my $taxon( @taxa ){ push(@{$sequenzen_alle{$taxon}}, $sequenzen{$taxon}) }
			}
			
			for my $taxon_aln(@taxa){
				
				my   @a = exists($sequenzen_alle{$taxon_aln}) ? @{$sequenzen_alle{$taxon_aln}} :() ;
				my   $sequenz_final = join "", @a                                                  ;
				push @{$input{$file_aln}}, ( ">".$taxon_aln , $sequenz_final )                     ;
			}	
		}
		
		sub phy2fas{
			
			my @file_phy = @_ ; &tie_linefeeds(@file_phy) ;
			
			open INphy , $file_phy[0] or die "$file_phy[0] can not be found!\n"  ;
			
			chomp (my @all_lines_phy = <INphy>) ; close INphy  ; 
			
			my 	$infoline_1   =  shift @all_lines_phy    ; 
			    $infoline_1   =~ s/\s+/ /                ;
			my 	@infos_line_1 =  split " ", $infoline_1  ; 
			my 	$tax_numb_phy =  $infos_line_1[0]        ;
			my 	%seq_phy      =  ()                      ;
			
			
			while ( @all_lines_phy ){
				
				for ( my $c=1; $c<=$tax_numb_phy; $c++ ){ my $seq_line_phy = shift @all_lines_phy ; push ( @{$seq_phy{$c}} , $seq_line_phy ) }
				shift @all_lines_phy ;
			}
			
			for my $line_c ( sort {$a<=>$b} keys %seq_phy ){ 
				
				my @seq_single_parts    =   exists($seq_phy{$line_c})  ? @{$seq_phy{$line_c}} :( ) ;
				my $seq_complete        =   join "", @seq_single_parts ; 
				$seq_complete        	=~  s/\s+/ / ;
				@seq_single_parts   	=   split " ", $seq_complete   ;
				my $taxon_phy           =   shift @seq_single_parts    ;
		           $taxon_phy      	    =~  s/$taxon_phy/>$taxon_phy/  ;
				$seq_complete       	=   join "", @seq_single_parts ;
				
				push @{$input{$file_phy[0]}}, ( $taxon_phy , $seq_complete ) ;
			} 
		}
		
		sub fasEDIT{
			
			my @file_fas = @_ ; &tie_linefeeds(@file_fas)  ;
			
			open INfas, $file_fas[0] or die "$file_fas[0] can not be found!\n"  ;
			
			chomp (my @fasfile = <INfas>)         ; close INfas ; 
			
			grep s/(\>.*)/$1\t/                   , @fasfile    ;
			grep s/ //g                           , @fasfile    ;
			grep s/\n//g                          , @fasfile    ;
			grep s/\t/\n/g                        , @fasfile    ;
			grep s/\>/\n\>/g                      , @fasfile    ;
			
			my   $fas_string        =  join  ""   , @fasfile    ;
			     @fasfile           =  split "\n" , $fas_string ;
			
			my   $first_newline     =  shift        @fasfile    ;
			if ( $first_newline  ){    die   "\n\t!FILE-ERROR!: Unknown input format of $file_fas[0] !\n" }
			@{$input{$file_fas[0]}} =               @fasfile    ;
		}
		
		sub tie_linefeeds{
			
			my @tie_file = @_ ;
			
			# Untei linefeeds
			TIE:
			(tie ( my @data, 'Tie::File', $tie_file[0] ))                                          ;
			
			print  "\n\t!FILE-ERROR!: $tie_file[0] is empty!\n" and next READING if 0 == @data     ;
			
			map { s/\r\n/\n/g } @data                                                              ;
			map { s/\r/\n/g   } @data                                                              ;
			
			untie @data                                                                            ;	
		}
		
	} 
	
	sub concatenate{
		
		my $counter_bp = 0 ;
		
		## CONCATENATE
		for my $file (  sort keys %input  ){
			
			my $aref_single_file =  exists($input{$file}) ? \@{$input{$file}} :( )  ;
			
			my %sequence                    =  @$aref_single_file         ;
			my $href_sequence               =  \%sequence                 ;
			my @sequences                   =  ( values %$href_sequence ) ;
			$href_number_merkmale->{$file}  =  length @sequences[0]       ;
			my $sref_range_anfang           =  ()                         ;
			my $sref_range_ende             =  ()                         ;
			
			# concatenate
			KEY:
			for my $taxon ( sort {$a<=>$b} keys %$href_namen ){
				
				my $sref_dots = (                                      )  ;
				$$sref_dots   = ( "." x $href_number_merkmale->{$file} )  ;
				
				if ( $href_sequence->{$taxon} ){ push ( @{$sequence_all{$taxon} } , $href_sequence->{$taxon} ) ; next KEY }
				if ( $struc_of_tax{$taxon}    ){ push ( @{$sequence_all{$taxon} } , $$sref_dots              ) ; next KEY }
				
				if ( $taxon_aa{$taxon}        ){ my $N_block = "X" x $href_number_merkmale->{$file} ;  push ( @{$sequence_all{ $taxon } }, $N_block ) }
				else{                            my $N_block = "N" x $href_number_merkmale->{$file} ;  push ( @{$sequence_all{ $taxon } }, $N_block ) }              
			}
			
			# range
			if   ( $href_number_merkmale->{$file} >  1 ){ 
				
				$counter_bp++                                                                          ;
				$$sref_range_anfang        = $counter_bp                                               ;
				$$sref_range_ende          = $$sref_range_anfang + $href_number_merkmale->{$file} - 1  ;
				$counter_bp                = $$sref_range_ende                                         ;
			}
			else { ( $$sref_range_anfang   , $$sref_range_ende ) = $counter_bp }
			
			# matrix startpoints
			$href_file_startpoint->{$file} = $$sref_range_anfang ;
			$href_file_endpoint->{$file}   = $$sref_range_ende   ;	
		}
		
		## DEREFERENZ
		for my $taxon( sort keys %$href_namen ){
			
			my $aref_final             = exists($sequence_all{$taxon}) ? \@{$sequence_all{$taxon}} :( ) ;
			
			my $number_conc            = @$aref_final                                                   ;
			$N_conc_taxon{$taxon}      = $number_conc                                                   ;
			my $sequence_final         = join "", @$aref_final                                          ;
			$number_merkmale{$out_fas} = length $sequence_final                                         ;
			
			if ( defined $struc_of_tax{$taxon} ){ $struc_of_file{$out_fas} = $sequence_final }
			
			push @{$input{$out_fas}}   , $taxon                                                         ;
			push @{$input{$out_fas}}   , $sequence_final                                                ;
		}
		
		$href_file_startpoint->{$out_fas}     = 1                                                       ;
		$href_file_endpoint->{$out_fas}       = $number_merkmale{$out_fas}                              ;
	}
	
	sub get_info{
		
		for my $file ( sort {$a<=>$b} keys %input ){
			
			my $aref_single_file                    = exists($input{$file}) ? \@{$input{$file}} :( )  ;
			
			my %sequence                            =   @$aref_single_file                ;
			my %counter                             =   (                               ) ;
			my @nc_state                            =   ( qw/A C G T U/                 ) ;
			my @am_state                            =   ( qw/N Y X R W S K M D V H B/   ) ;
            my @mi_state                            =   ( qw/?/                         ) ;			
			my @as_state                            =   ( qw/F L I P Q E/               ) ;
			my $ga_state                            =   "-"                               ;
			my $href_counter                        =   \%counter                         ;
			my $href_sequence                       =   \%sequence                        ;
			my $number_taxa_file                    =   keys %$href_sequence              ;
			
			
			for ( @nc_state ){ $href_counter->{$_}  =   0                                 }
			$href_counter_ambs->{$file}             =   0                                 ;
			$href_N_characters->{$file}             =   0                                 ;
			$href_counter_misdata->{$file}          =   0                                 ;
			$href_seq_type->{$file}                 =   "Nucleotide"                      ;
			$href_Ntax_of_file->{$file}             =   $number_taxa_file                 ;  
			
			
			
			# Determine Numbers of different character states
			for my $tax_single ( keys %$href_sequence  ) {
				
				my @parts        = split ( "", $href_sequence->{$tax_single} ) ;
				my $aref_parts   = \@parts ;
				
				for my $ch_state ( @$aref_parts ){ $href_N_characters->{$file}++ ; $href_counter->{$ch_state}++ }
				
				for my $am_state ( @am_state    ){ $href_counter_ambs->{$file}        +=  $href_counter ->{$am_state} ; $href_counter->{$am_state} = 0 }
				for my $mi_state ( @mi_state    ){ $href_counter_misdata->{$file}     +=  $href_counter ->{$mi_state} ; $href_counter->{$mi_state} = 0 }
				for my $as_state ( @as_state    ){ defined $href_counter->{$as_state}  ?  $href_seq_type->{$file}     = "Amino acid" : ()              }
				
				$href_counter_gaps->{$file} = $href_counter->{$ga_state} ;
			}	
			
			my $number_taxa_total                   =   ( keys %$href_namen                            ) ;
			my $N_inserted_rows                     =   ( $number_taxa_total - $number_taxa_file       ) ;
			$href_counter_tax_inserted->{$file}     =     $N_inserted_rows                               ;
			$href_counter_N_inserted  ->{$file}     =   ( $N_inserted_rows   * $number_merkmale{$file} ) ;
			$href_counter_N_inserted  ->{Smatrix}  +=     $href_counter_N_inserted->{$file}              ;
			
			
			# Prepare OUTput infos
			if ( $href_seq_type->{$file}      =~ "Nucleotide"      ){ for ( @nc_state ){ push @{ $single_infos_of_file{$file} }, $href_counter->{$_} } ; $counter_total{nucleo}++ }
			if ( $href_seq_type->{$file}      =~ "Amino acid"      ){ for ( 0 .. 4    ){ push @{$single_infos_of_file{$file}  }, " not considered"     ; $counter_total{amino}++  }
				 $href_counter_ambs->{$file}  =  " not considered"
			}
		}
	}
	
	sub structure_handling{
		
		# STRUCTURE_FILE
		for my $file ( sort keys %$href_struc_of_file ){
			
			
			my @pair_infos                =  ()           ;  my $aref_i          = \@pair_infos ;
			my @forward                   =  ()           ;  my $aref_f          = \@forward    ;
			my @loops                     =  ()           ;  my $aref_l          = \@loops      ;
			my @pairs                     =  ()           ;  my $aref_p          = \@pairs      ;
			
			$href_struc_of_file->{$file}  =~ s/-/./g      ;
			my @structures                =  split ( ""   , $href_struc_of_file->{$file} )      ;
			my $aref_structures           =  \@structures ;
			
			
			# Stem assignment
			my  $i = 0 ;
			
			CHECKING:
			for ( @$aref_structures ){ $i++ ;
				
				if ( $_  =~ /\(/ ){                                                               push @$aref_f ,   $i               ; next CHECKING  }
				if ( $_  =~ /\)/ ){ my $pair_1 = pop @$aref_f ; push @$aref_p , ( $pair_1, $i ) ; push @$aref_i , ( $pair_1.":".$i ) ; next CHECKING  }
				if ( $_  =~ /\./ ){                                                               push @$aref_l ,   $i               ; next CHECKING  }
			}
			
			@pair_infos  =  reverse @pair_infos          ;
			
			
			# Generate listfiles for structure_info file
			my $pairlist =  join ( "," , @$aref_i ) ;
			my $stemlist =  join ( " " , @$aref_i ) ;
		       $stemlist =~ s/:/ /g                 ;
			my $looplist =  join ( " " , @$aref_l ) ;
			
			
			# Number and proportion of stem and loop positions for structure info file
			my $N_bps_struc                  =    @$aref_structures                                                            ; 
			$href_N_total->{$file}           =    $N_bps_struc                                                                 ;
			$href_N_loops->{$file}           =    @$aref_l                                                                     ;
			$N_stems{$file}                  =    $N_total{$file} -   $N_loops{$file}                                          ;
			my $p_loops                      =    sprintf "%.1f"  , ( $N_loops{$file} / $N_total{$file} )           * 100      ;
			my $p_stems                      =    sprintf "%.1f"  , ( 100 - ( ( $N_loops{$file} / $N_total{$file} ) * 100 ) )  ;
			#$p_loops                         =~   s/\./,/                                                                      ;
			#$p_stems                         =~   s/\./,/                                                                      ;
			$href_P_loops->{$file}           =    $p_loops                                                                     ;
			$href_P_stems->{$file}           =    $p_stems                                                                     ;
			$href_file_struc_pairs->{$file}  =    $pairlist                                                                    ;
			$href_file_struc_stems->{$file}  =    $stemlist                                                                    ;
			$href_file_struc_loops->{$file}  =    $looplist                                                                    ;
		}
	}
	
	sub print_out{
		
		
		# SMATRIX OUTPUT
		my @smatrix         =  exists($input{$out_fas}) ? @{$input{$out_fas}} :( ) ;
		my $aref_smatrix    =  \@smatrix                                           ;
		my $string_smatrix  =  join ( "\n", @$aref_smatrix )                       ; # FASTA
		
		open  OUT_smatrix,  ">$out_fas" or warn "\n\t!FILE-ERROR!: Can not open $out_fas" ;
		print OUT_smatrix   "$string_smatrix\n" ; 
		close OUT_smatrix;
		
		
		
		#INFO OUTPUT PART GENE SEQUENCES
		$parameter_phy[0]  =~ /STRICT|RELAXED/ ? ( &fas2phylip( @$aref_smatrix ) ) : ( ) ;
		$parameter_info[0] =~ "NO"             ? ( &info_small  ) : ( &info_all  ) ;
		$parameter_nex[0]  =~ /BLOCK|MrBAYES/  ? ( &nexus_block ) : ( &end       ) ;
		
		sub info_small{
			
			open  OUT_info, ">$out_info" or warn "\n\tCan not open $out_info!" ;
			
			print OUT_info "FASconCAT infofile\n\nFiles concatenated\tRange smatrix\n" ;
			for my $file  ( sort {$a<=>$b} keys %$href_input ){ print OUT_info "$file\t$href_file_startpoint->{$file} => $href_file_endpoint->{$file}\n" }
			
			# TAXONCHECK OUTPUT
			print OUT_info "\n\nTaxon check\nTaxon\tN concatenated\n" ;
			for my $taxon ( sort {$a<=>$b} keys %$href_namen ){ print OUT_info "$taxon\t$N_conc_taxon{$taxon}\n" }
			
			close OUT_info ;
		}	
		
		sub info_all{
			
			my $info_text_head = "FASconCAT infofile\n\nFilename\tNumber of taxa\tSequence length [bp]\tSMATRIX-Range\tSequence type\tNumber of characters in total\tA\tC\tG\tT\tU\tNumber of gaps\tNumber of Ambiguities\tNumber of missing data (?)\tNumber of missing taxa\tNumber of inserted X/N's for missing taxa\n" ;
			my $info_text_bott = "\n\nSupermatrix\nNumber of characters\tNucleotides [%]\tAmbiguities [%]\tGaps [%]\tInserted N/X [%]\tMissing data [%]\n" ;
			
			
			$href_counter_N_inserted->{$out_fas} = $href_counter_N_inserted->{Smatrix} ;
			
			my $number_cha_total =                 (   $href_number_merkmale->{$out_fas}     * $href_Ntax_of_file->{$out_fas} ) ; 
			my $perc_nuc_smatrix = sprintf "%.3f", ( ( $number_cha_total - $href_counter_ambs->{$out_fas} - $href_counter_gaps->{$out_fas} - $href_counter_N_inserted->{$out_fas} - $href_counter_misdata->{$out_fas} ) / $number_cha_total ) * 100 ;	
			my $perc_amb_smatrix = sprintf "%.3f", (   $href_counter_ambs->{$out_fas}        /  $number_cha_total ) * 100       ;
			my $perc_gap_smatrix = sprintf "%.3f", (   $href_counter_gaps->{$out_fas}        /  $number_cha_total ) * 100       ;
			my $perc_Nin_smatrix = sprintf "%.3f", (   $href_counter_N_inserted->{$out_fas}  /  $number_cha_total ) * 100       ;
			my $perc_mis_smatrix = sprintf "%.3f", (   $href_counter_misdata->{$out_fas}     /  $number_cha_total ) * 100       ;
			
			if ( ( defined $counter_total{nucleo} ) && ( $counter_total{amino} ) ){ $href_seq_type->{$out_fas} = "Amino acid / Nucleotide" }
			
			open  OUT_info, ">$out_info" or warn "\n\tCan not open $out_info!" ;
			print OUT_info  $info_text_head ;
			
			for my $file ( sort keys %$href_input ){ 
				
				my @nuc_info = exists( $single_infos_of_file{$file} ) ? @{$single_infos_of_file{$file}} : () ;
				my $nuc_info = join "\t" , @nuc_info ;
				
				print OUT_info "$file\t$Ntax_of_file{$file}\t$href_number_merkmale->{$file}\t$href_file_startpoint->{$file} => $href_file_endpoint->{$file}\t$href_seq_type->{$file}" ;
				print OUT_info "\t$href_N_characters->{$file}\t$nuc_info\t$href_counter_gaps->{$file}\t$href_counter_ambs->{$file}\t$href_counter_misdata->{$file}\t$href_counter_tax_inserted->{$file}\t$href_counter_N_inserted->{$file}\n" ;
			}			
			
			print OUT_info  "$info_text_bott $number_cha_total\t$perc_nuc_smatrix\t$perc_amb_smatrix\t$perc_gap_smatrix\t$perc_Nin_smatrix\t$perc_mis_smatrix\n\n";
			
			
			if ( $struc_of_file{$out_fas} ){
				
				# INFO OUTPUT PART STRUCTURE SEQUENCES
				print OUT_info "\nFASconCAT.v1.0.pl Structure info\nFile with structure\tNumber of unpaired characters\tUnpaired [%]\tNumber of paired characters\tPaired [%]\n" ;
				
				for my $file ( sort  keys %$href_struc_of_file ){ print OUT_info "$file\t$href_N_loops->{$file}\t$href_P_loops->{$file}\t$href_N_stems->{$file}\t$href_P_stems->{$file}\n" }
				
				# STRUKTUR OUTPUT
				open  OUT_struc, ">FcC_structure.txt" or warn "\n\t!FILE-ERROR: Can not open FcC_smatrix_structure.txt" ;
				print OUT_struc  "FASconCAT structure info of $out_fas\n\nStructure-string\n" ;
				print OUT_struc  "$href_struc_of_file->{$out_fas}\n\nLoop positions\n" ;
				print OUT_struc  "$href_file_struc_loops->{$out_fas}\n\nStem positions\n$href_file_struc_stems->{$out_fas}\n\nStem pairings\n$href_file_struc_pairs->{$out_fas}\n" ;
				close OUT_struc ;
			}
			
			
			
			# TAXONCHECK OUTPUT
			print OUT_info "\n\nTaxon check\nTaxon\tN concatenated\n" ;
			for my $taxon ( sort {$a<=>$b} keys %$href_namen ){ print OUT_info "$taxon\t$N_conc_taxon{$taxon}\n" }
			close OUT_info ;
		}	
		
		sub nexus_block{
			
			# MrBAYES - PARAMETER
			my $partition_looms = "partition looms = 2: loops, stems;"       ;
			my $set_partition   = "set partition = looms;"                   ;
			my $lset_applyto1   = "lset applyto= (1) nucmodel= 4by4;"        ;
			my $lset_applyto2   = "lset applyto= (2) nucmodel= dublet;"      ;
			my $lset_applyto12  = "lset applyto= (1,2) nst= 6 rates= gamma;" ;
			
			# NEXUS - BLOCK - PARAMETER
			my $format          = "format datatype=dna interleave"           ;
			my $missing         = "missing=-;"                               ; 
			my $autoclose       = "set autoclose= yes"                       ;
			my $nowarn          = "nowarn=yes;"                              ;
			my $state_freq      = "unlink statefreq= (all)"                  ;
			my $tratio          = "tratio= (all)"                            ;
			my $shape           = "shape= (all);"                            ;
			my $mcmc_gen        = "mcmc ngen= 2000"                          ;
			my $print_freq      = "printfreq= 100"                           ;
			my $sample_freq     = "samplefreq= 100"                          ;
			my $nchains         = "nchains= 4"                               ;
			my $save_brlens     = "savebrlens= yes"                          ;
			my $sump_burnin     = "sump burnin= 20"                          ;
			my $nruns           = "nruns= 2;"                                ;
			
			
			
			## CONVERT FASTA NON-INTERLEAVED TO FASTA INTERLEAVED FORMAT
			my %seq_parts_nex      = () ; my $href_seq_parts_nex = \%seq_parts_nex ;
			my %counter_nex        = () ; my $href_counter_nex   = \%counter_nex   ;
			my $bayes_block_string = () ;
			
			my @single_file_nex    =  exists($input{$out_fas}) ? @{$input{$out_fas}} :( ) ;
			my %seq_nex            =  @single_file_nex ;
			my $href_seq_nex       =  \%seq_nex        ;
			
			
			for my $nex_tax ( sort {$a<=>$b} keys %$href_seq_nex ){
				
				my @bps_nex        = split ( "" , $href_seq_nex->{$nex_tax} ) ;
				my $aref_bps_nex   = \@bps_nex  ;
				
				my @sub_parts_nex  = () ; my $aref_sub_parts_nex  = \@sub_parts_nex  ;
				my @block_rows_nex = () ; my $aref_block_rows_nex = \@block_rows_nex ;
				
				$href_counter_nex->{blocks} = 0 ;
				
				my ( $k, $j ) = 0 ;
				
				for my $single_bp_nex ( @$aref_bps_nex ){
					
					push @$aref_sub_parts_nex, $single_bp_nex ; $j++ ;
					
					if ( $j =~ 20 ){
						
						my $string_nex = join "", @$aref_sub_parts_nex ; 
						push @$aref_block_rows_nex, $string_nex ; $k++ ; @$aref_sub_parts_nex = () ; $j = 0 ;
						
						if ( $k =~ 5 ){ 
							
							push @{ $seq_parts_nex{$nex_tax}} , ( my $string_row_nex = join ( " ", @$aref_block_rows_nex ) ) ; @$aref_block_rows_nex = () ; 
							$k = 0 ; $href_counter_nex->{blocks}++ 
						}
					}
				}
				
				if ( defined @$aref_sub_parts_nex  ){ my $string_nex = join ( "", @$aref_sub_parts_nex ) ; push @$aref_block_rows_nex , $string_nex }
				if ( defined @$aref_block_rows_nex ){ push @{ $seq_parts_nex{$nex_tax}} , ( my $string_row_nex = join ( " ", @$aref_block_rows_nex ) ) ; $href_counter_nex->{blocks}++ }
			}
			
			
			my $out_fas_cp =  $out_fas  ;
			$out_fas_cp    =~ s/.fas//  ;
			
			## GENERATE NEXUS-BLOCK WITH MR BAYES COMMAND LINES
			my $ntax_nex = $href_Ntax_of_file->{$out_fas} ;
			
			if   ( defined $struc_tax{reference} ) {
				
				my $N_struc_taxa       = keys %$href_struc_of_tax ;
				   $ntax_nex           = $href_Ntax_of_file->{$out_fas} - $N_struc_taxa ;
				   $bayes_block_string = "\n\nbegin mrbayes;\ncharset loops= $href_file_struc_loops->{$out_fas} ;\ncharset stems= $href_file_struc_stems->{$out_fas} ;\n\npairs $href_file_struc_pairs->{$out_fas} ;\n\n$partition_looms\n\n$set_partition\n$lset_applyto1\n$lset_applyto2\n$lset_applyto12";
			}
			else{ $bayes_block_string  = "\n\nbegin mrbayes;\n lset nst= 6 rates= gamma;\n\n" }
			
			
			# HEAD_NEXUS
			open  OUT_nex, ">$out_fas_cp.nex" or warn "\n\t!FILE-ERROR !:Can not open $out_fas_cp.nex\n" ;
			print OUT_nex  "#NEXUS\n\nbegin data;\n dimensions ntax= $ntax_nex nchar= $href_number_merkmale->{$out_fas};\n $format $missing\n matrix\n" ;
			
			NEXUS_BLOCK:
			for my $row( 0 .. $href_counter_nex->{blocks}-1 ){
				
				HERE:
				for my $taxon ( sort {$a<=>$b} keys %$href_seq_parts_nex ){
					
					if ( $struc_of_tax{$taxon} ){ next HERE }
					
					my @block_parts = exists ( $seq_parts_nex{$taxon} ) ? @{$seq_parts_nex{$taxon}} : () ;
					my $string_row  = join " ", $block_parts[$row] ;
					
					$taxon =~ s/\>/ / ;
					print OUT_nex "$taxon  $string_row\n" ;
				}			
				
				print OUT_nex "\n" ;
			}
			
			
			BOTTOM_NEXUS:
			if ( $parameter_nex[0]  =~ "BAYES" ){
				
			   print OUT_nex ";\n end;\n log start file= $out_fas_cp.txt append;\n\n\n$bayes_block_string\n\n showmodel;\n $autoclose $nowarn\n $state_freq $tratio $shape\n $mcmc_gen $print_freq $sample_freq $nchains $save_brlens filename= $out_fas ;\n $sump_burnin nruns= 2;\n sumt burnin= 10 $nruns\n\n quit;\n" ;
			}
			else { print OUT_nex ";\n end;\n log start file= $out_fas_cp.txt append;\nend ;\n" }
			
			close OUT_nex
		}	
		
		sub fas2phylip{
			
			my @fas_format = @_                ; my $aref_fas_format = \@fas_format ;
			my %matrix_seq = @$aref_fas_format ; my $href_matrix_seq = \%matrix_seq ;
			
			my $N_taxa     = keys   %$href_matrix_seq     ;
			my $N_char     = length $aref_fas_format->[1] ;
			
			open  OUTphy,  ">FcC_smatrix.phy" or warn "\n\t!FILE-ERROR!: Can not open FcC_smatrix.phy !" ;
			print OUTphy   "$N_taxa $N_char\n" ;
			
			# RELAXED
			if ( $parameter_phy[0]  =~ /RELAXED/ ){ 
				
				my $sign_length = 10 ;
				
				for my $matrix_tax ( keys %$href_matrix_seq ){ 
					
					( my $matrix_t = $matrix_tax ) =~ s/^>// ; 
					
					my $N_signs    = length $matrix_t ;
					if ( $N_signs  > $sign_length ){ $sign_length = $N_signs }
				}
				
				for my $matrix_tax ( keys %$href_matrix_seq ){ 
					
					( my $matrix_t = $matrix_tax ) =~ s/^>// ; 
					
					my $left_signs = () ;
					my $N_signs2   = length $matrix_t ;
					
					if ( $N_signs2 < $sign_length ){ $left_signs = $sign_length - $N_signs2 }
					
					print OUTphy "$matrix_t" ; 
					for ( 1 .. $left_signs ){ print OUTphy " "}
					print OUTphy " $href_matrix_seq->{$matrix_tax}\n" 
				}
			}
			
			# STRICT
			else{
				
				for my $matrix_tax ( keys %$href_matrix_seq ){ 
					
					#( my $matrix_t = $matrix_tax ) =~ s/^>// ;
					my $substr = substr($matrix_tax, 1, 10) ;
					
					my $substr_end  = () ;
					my $lght_substr = length $substr ;
					
					if ( $lght_substr < 10 ){ 
						
						my $N_blanks   =  ( 10 - ( length $substr )  ) ; 
						my $blanks     =  ( "_" x  $N_blanks         ) ;
						$substr_end =    $substr.$blanks            ;
					}
					
					else { $substr_end = $substr }
					
					print OUTphy "$substr_end $href_matrix_seq->{$matrix_tax}\n"
				}
			}
			close OUTphy;	
		}
	}
	
	sub end{
		
		print "\n\n\t------------------------------------------------------------\n"   ;
		print  "\t#### FASconCAT: DONE ! ####\n"                                       ;
		print "\n\t-Supermatrix printed out to 'FcC_smatrix.fas'"                      ;
		
		if ( defined $struc_tax{reference} && $parameter_info[0] =~ "YES"     ){ print "\n\t-Structure strings printed out to FcC_smatrix_structure.txt" }
		if (                                  $parameter_nex[0]  =~ /BLOCK/   ){ print "\n\t-NEXUS BLOCK printed out to FcC_smatrix.nex"                 }
		if (                                  $parameter_nex[0]  =~ /MrBAYES/ ){ print "\n\t-Mr.BAYES NEXUS BLOCK printed out to FcC_smatrix.nex"        }
		
		print "\n\t-Summarized INFOS printed out to FcC_info.xls\n\n" ;
		
		TIMER:
		# set timer
		my ( $user, $system, $cuser, $csystem ) = times ;
		
print <<TIME;
		
			***  time used: $user sec  ***
		
TIME
		
		print "\n\t------------------------------------------------------------\n"     ;
		
		exit
	}
}

sub commandline{

	my ($errorreport) = @_    ;
	print  "\n\t$errorreport" ;
	print  "\n\tCOMMAND:\t "  ;
	
	chomp ( my $sub_answer_opening = <STDIN> );

	print  "\n\t------------------------------------------------------------\n" ;
	
	return $sub_answer_opening;
}	

	

	
	





