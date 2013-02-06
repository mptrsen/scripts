
=head1 CYOOSH UTILITIES

Provides subroutines that are used by CYOOSH.pl (Create Your Own Ortholog Set for HAMSTR). 

"Calls" within a subroutine's description refers only to subs of this package.
Arguments / subroutines in square brackets ([]) are not necessary for proper running.

=head1 SYNOPSIS

use lib '...' ;      
 # If package and program are in the same folder -> (UNIX): '.' 
 # To be sure just write the entire path

use CYOOSH_Utilities ('all subs', 'separated by commas');
 # Copy from @EXPORT_OK
 # Subroutines marked with [] may be omitted, but it is recommended 
   to use them

The subroutines are exported, so you can call the subs as if they were declared 
whithin CYOOSH.pl

=cut

package CYOOSH_Utilities;

use strict;
use warnings;

use Data::Dumper;
use Carp;
use File::Path qw(make_path remove_tree);
use File::Spec::Functions;
use File::Copy;
use Tie::File;

use Exporter 'import';
our @EXPORT_OK = ('read_CYOOSH_config', 'create_HAMSTR_input_tree', 
                    'mk_dir', 'adjust_all_fa_headers', 'align_all', 
                    'convert_all_to_stockholm', 'build_all_hmms', 
                    'compile_all_core_orthologs_AA', 'compile_all_core_orthologs_NT',
                    'prepare_blast_db', 
                    'make_blast_db', 'slurp_fasta', 'slurp_file', 'read_dir', 
                    'save_config_in_set', 'print_empty_files', 'remove_dir');

my $n = "\n";

#############################################################################

=head1 SUBROUTINES

=head2 CONTENTS

    01. read_CYOOSH_config
    02. create_HAMSTR_input_tree
    03. make_dir
    04. adjust_all_fa_headers
    05. align_all
    06. convert_all_to_stockholm
    07. build_all_hmms
    08. compile_all_core_orthologs_AA
    09. compile_all_core_orthologs_NT
    10. prepare_blast_db
    11. make_blast_db
    12.slurp_fasta
    13. slurp_file
    14. read_dir
    [15. save_config_in_set]
    [16. print_empty_files]
    
=cut

##############################################################################

=head2 01. read_CYOOSH_config

 Usage   : my ( $config_info_of_REF, 
           $config_taxon_info_of_REF, $path_to_config ) 
           = &read_CYOOSH_config;
 Function: Reads the provided CYOOSH config and 
           stores the further on needed information in two 
           hashes (general information on paths etc / taxa 
           information). Checks on the fly for config syntax
           errors and whether stated paths are valid and 
           programs are executable.
 Calls   : slurp_file
 Returns : References of the two info hashes (info_of 
           and taxon_info_of) and the path to the config file
 Args    : none, but needs the path to the config file 
           provided via @ARGV

=cut

sub read_CYOOSH_config {
    die "Missing or superfluous arguments in program call! $n ARGV needs to be the path to your CYOOSH config. $n"
        if scalar @ARGV != 1;

    my $path_to_config = shift @ARGV;
    
    print 'Reading Config...', $n;
  
    die "Path to config does not exist! $n" if !-e $path_to_config;
    
    my @lines = &slurp_file( $path_to_config );
    chomp @lines;
    
    my %config_info_of;
    my %config_taxon_info_of;
    # distinguish INFO (= 1) and TAXA (= 2)
    my $category_flag = 0; 
    
    foreach my $line ( @lines ) {
        # define hash to write in via catergory
        $category_flag = 1 if $line =~ m/INFO/;
        $category_flag = 2 if $line =~ m/TAXA/;
        
        # ignore comments and empty lines (do not put them into hash)
        next if $line =~ m/(^#)|(^\s*$)/;
        
        if ( $category_flag == 0 ) {
            die "Config format wrong. INFO and TAXA specifying lines are missing! $n"
        }
        # info part
        elsif ( $category_flag == 1 ) {
            # -> info_items: 0->info     1-=     2-path/statement     3-#     4-comment 
            my @info_items = split ( /\s+/, $line );
            
            die "Missing or superfluous arguments in config info ($line)! $n Stick to the fixed pattern! $n" 
                if (scalar @info_items != 3);
                            
            # populate info hash with dir name and path
            $config_info_of{$info_items[0]} = $info_items[2];
        }
        # taxa part
        elsif ( $category_flag == 2 ) {
            # -> taxon_items: 0-fullname    1-abbr.      2-OGSversion    3-comment
            my @taxon_items = split ( /\s+/, $line );
            
            die "Format of config (taxa) is not right! $n Check line \"$line\"! $n" 
                if ( scalar @taxon_items < 3 );
        
            my $taxon = join ( ',', @taxon_items );
            $config_taxon_info_of{$taxon_items[1]} = $taxon;
        }
    }
    
    # spelling check (info) & path check
    my @infos = ( 'path', 'set_name', 'adjust_aa_headers', 'stockh_header_width',
                  'align_all', 'mafft_or_muscle', 'path_to_orig_AA', , 'path_to_orig_NT',
                  'path_to_orig_prot', 'path_to_linsi_prog', 
                  'path_to_einsi_prog', 'path_to_muscle_prog', 'overwrite',
                  'path_to_hmmbuild_prog', 'path_to_mkblastdb_prog',
                  'path_to_exonerate_prog' );
                            
    foreach my $info ( @infos ) {
        # if align is not chosen, alignment program paths can be ignored
        next if ( $config_info_of{'align_all'} =~ m/no/i && $info =~ m/linsi|einsi|muscle/i);
        # check whether path exists
        die "Path of $info (config) does not exist! $n" 
            if ( $config_info_of{$info} =~ m/\// && !-e $config_info_of{$info} ); 
        die "Misspelled or missing info in config ($info)! $n" 
            if !exists $config_info_of{$info};
    }
    
    # check options (info)
    die "Invalid option in config ('adjust_aa_headers')! $n" 
        if $config_info_of{'adjust_aa_headers'} !~ m/yes|no/i;
    
    die "Invalid option in config ('adjust_aa_headers')! $n" 
        if $config_info_of{'adjust_nt_headers'} !~ m/yes|no/i;
        
    die "Invalid option in config ('align_all')! $n Choose yes or no!" 
        if $config_info_of{'align_all'} !~ m/yes|no/i;
        
    die "Invalid option in config ('overwrite')! $n Choose yes or no!" 
        if $config_info_of{'overwrite'} !~ m/yes|no/i;
        
    if ($config_info_of{'align_all'} =~ m/yes/i) {
        die "Invalid option in config ('mafft_or_muscle')! $n Choose mafft_linsi, mafft_einsi or muscle! $n" 
            if $config_info_of{'mafft_or_muscle'}!~ m/mafft_linsi|mafft_einsi|muscle/i;
    }
    die "Invalid option in config ('stockh_header_width')! $n Choose an integer between 0 and 255! $n"
        if $config_info_of{'stockh_header_width'} !~ m/^([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])$/;
        
    # check whether programs are executable
    my @program_keys = grep {m/prog/} ( keys %config_info_of );
    foreach my $program_key ( @program_keys ) {
        next if ( $config_info_of{'align_all'} !~ m/no/i && $program_key =~ m/linsi|einsi|muscle/i);
        die "Program $program_key is not executable! Check your statement (config) or install program resp.! $n" 
            if !-x $config_info_of{$program_key};
    }   

    print "Config read! $n $n";
    return \%config_info_of, \%config_taxon_info_of, $path_to_config;
}

##############################################################################

=head2 02. create_HAMSTR_input_tree

 Usage   : my ($path_into_REF, $new_set_dir) = &create_HAMSTR_input_tree
           ($path_to_destination, $set_name, $overwrite_info);      
 Function: Sets up the general directory tree as required 
           by HAMSTR. Those directories below marked with * 
           should already be present but are created if not.
           In the config you can choose, whether you want to 
           overwrite already existing folders or not. 
           Directories of lower order (marked with ') are created later 
           in other subroutines. 
           Stores names of directories and their corresponding path
           into a hash.
            
           Tree:
           + HAMSTR *
               +core_orthologs *
                   + set_name_HMMer3
                       + fa_dir 
                       + aln_dir  
                           + aligned_fa (if 'align_all' = yes) '
                       + hmm_dir
               + blast_dir *
                   + species_specific_dir (one for each) '
 Calls   : make_dir
 Returns : hash (dir => path) storing the most important paths to 
           the directories of the newly created tree
 Args    : Path (destination where the new set will be stored (excl. 
           'HAMSTR'!), the desired set name and overwrite info for 
           make_dir)
        
=cut 

sub create_HAMSTR_input_tree {
    my ( $path, 
         $set_name,
         $overwrite_info) = @_;
         
    print 'Creating dir tree...', $n;
    
    my $parent              = catdir ($path, 'HAMSTR');
    my $core_orthologs_dir  = 'core_orthologs';
    my $new_set_dir         = $set_name.'_HMMer3';  
    my $new_co_dir          = catdir ( $core_orthologs_dir, $new_set_dir );
    my @subdirs             = ( 'aln_dir', 'fa_dir', 'hmm_dir', 'tmp_dir' );

    my %path_into;

    foreach my $dir ( @subdirs ) {
        my $dir_name = $dir;
        $dir         = catdir( $new_co_dir, $dir );
        $dir         = catdir ( $parent, $dir );   
        
        make_dir( $overwrite_info, $dir )
            or croak "Make_dir failed ($dir)! $n";
            
        #save relevant paths in hash (dir => path)
        $path_into{$dir_name} = $dir; 
    }
    
    $path_into{'_HMMer3'}   = catdir($parent, $new_co_dir); # path to set_HMMer3
    $path_into{'blast_dir'} = catdir($parent, 'blast_dir');
		#mp create blast_dir if it doesn't exist
		if (!-e $path_into{'blast_dir'}) {
			make_dir( $overwrite_info, $path_into{'blast_dir'} )
					or croak "Make_dir failed ($path_into{'blast_dir'})! $n";
		}
		#mp end create blast_dir
   
    print 'Created tree!',$n,$n;   
    return \%path_into;
}

##############################################################################

=head2 03. make_dir

 Usage   : make_dir($overwrite_info, $dir)
 Function: Creates a new dir, depending on the 
           option chosen for 'overwrite' in the config.
 Calls   : -           
 Returns : 1 (can be checked in main program / calling subroutine)
 Args    : Overwrite_info (yes /no) to decide whether an existing 
           directory will be deleted and recreated or not,
           path and directory name in one variable

=cut

sub make_dir {
    my ( $overwrite_info,
         $dir ) = @_;
         
    die "Dir \"$dir\" already exists! Delete or rename set! $n"
        if ( $overwrite_info =~ m/no/ && -e $dir );
    if ( $overwrite_info =~ m/yes/ && -e $dir ) {
        remove_tree($dir);
    }
    make_path( $dir )
        or croak "Cannot create dir $dir: $! $n";

		print "Removed and recreated $dir. $n";
    return 1;
}

sub remove_dir {
	my $dir = shift;
	remove_tree($dir) or return $!;
	print "Removed temporary directory $dir.\n";
	return 1;
}

##############################################################################

=head2 04. adjust_all_fa_headers

 Usage   : &adjust_all_fa_headers( $modus_operandi, 
           $config_taxon_info_of_REF, $config_info_of_REF, 
           $path_to_orig_fastas,  $path_output, [\%empty_files]);
 Function: Modifies the headers of all provided original amino acid
           or nucleotide fastas -> inserts orthologous gene name and 
           (if the option is chosen in the config file) genome version.
           The fastas will be stored in fa_dir (AA-sequences) or 
           tmp_dir (nucleotide-sequences) within the new set 
           directories.
 Calls   : read_dir, slurp_fasta
 Returns : 1 (can be checked in main program) 
 Args    : Modus operandi ('AA' / 'NT'), references of config info and 
           taxon info, path to original fastas, path to output directory 
           (fa_dir for AA, tmp_dir for NT)
           [and reference of the hash storing empty files 
           (needed by slurp_fasta, further information there)]
 
=cut

sub adjust_all_fa_headers {
    my ( $modus_operandi,
         $config_taxon_info_of_REF, 
         $config_info_of_REF, 
         $path_to_orig_fastas, 
         $path_output_files, 
         $empty_files_REF ) = @_;
    
    # define conditions for adjustment
    my $adjust_condition;
    if ( $modus_operandi =~ m/AA/ ) {
        print 'Adjusting AA headers...', $n;
        if ( ${$config_info_of_REF}{'adjust_aa_headers'} =~ m/yes/ ) {
            $adjust_condition = 1; 
        }
        elsif ( ${$config_info_of_REF}{'adjust_aa_headers'} =~ m/no/ ) {
            $adjust_condition = 0;
        }
    }
    elsif ( $modus_operandi =~ m/NT/) {
        print 'Adjusting NT headers...', $n;
        if ( ${$config_info_of_REF}{'adjust_nt_headers'} =~ m/yes/ ) {
            $adjust_condition = 1; 
        }
        elsif ( ${$config_info_of_REF}{'adjust_nt_headers'} =~ m/no/ ) {
            $adjust_condition = 0;
        }        
    }
    
    my @fasta_files = &read_dir( $path_to_orig_fastas );
  
    foreach my $file ( @fasta_files ) {     
        my ( $seq_of_REF, $headers_REF ) = slurp_fasta( $file, $empty_files_REF, 
            $path_to_orig_fastas )
            or croak "Cannot slurp fasta $file ($path_to_orig_fastas) $n";
        
        # skip empty files
        next if scalar @{$headers_REF} == 0;

        # open output (manip header, new location) file
        $file             =~ m/^(\w+)(\.fa(s)?)$/;	#mp modified regex, wouldn't match files otherwise
        my $file_out      = $1.$2;
        my $file_out_path = catfile( $path_output_files, $file_out );
        open ( my $FH_out, '>', $file_out_path )     
            or croak "Cannot open \"$file\": $! $n";
       
        # orthologous gene -> only alphanumerics --> part to insert 
        $file          =~ m/^(\w+)\./;                                    # ----retrived from file name = DANGEROUS          
        my $ortho_name = $1;
        
        # go through all lines of fasta to adjust headers (insert file name / gene name)
        foreach my $header ( @{$headers_REF} ) {        
            #              1.> 2.spec.abr  3.| 4.whatever  
            $header        =~ m/(>)(\w+)(\|)?(.+)?/;   

            # insert gene name                                                  
            my $new_header = $1.$ortho_name.'|'.$2;
            if ( !defined $3 ) {
                $new_header .= '|'; 
            }
            else {
                $new_header .= $3;
            }
            if ( defined $4 ) {
                $new_header .= $4;
            }
             
            my $spec_name  = $2; 
            
            # adjust headers (insert OGS version), when option is chosen                                                                                            
            if  ( $adjust_condition == 1 ){ 
                ## search for version number based on spec name
                foreach my $taxon_abbr ( keys %{$config_taxon_info_of_REF} ) {          
                    if ( $taxon_abbr eq $spec_name ) {
                        my @taxon_info = split ( ',', ${$config_taxon_info_of_REF}{$taxon_abbr} );
                        #              ortho|spec-abbr|whatever
                        $new_header =~ m/(>\w+\|\w+)(\|)(.+)?/;
                        # insert version number
                        $new_header = $1.'_'.$taxon_info[2].$2; 
                        if ( defined $3 ) {
                            $new_header .= $3;
                        }
                        last;
                    }
                } 
            }            
            # print header and unchanged sequence to new directory / file         
            print {$FH_out} $new_header,$n;     
            print {$FH_out} ${$seq_of_REF}{$header},$n; 
        }
        close $FH_out;
    }
    print "Headers adjusted! $n$n";
    return 1;

}

##############################################################################

=head2 05. align_all
 
 Usage   : &align_all ($config_info_of_REF, 
           $path_input_files, $path_output_files, $overwrite_info)    
           if 'align_all' =~ m/yes/i;
 Function: If this option is chosen in CYOOSH config, it 
           aligns fastas from fa_dir and stores them in a new 
           directory (aligned_fa) within aln_dir.
           Depending on the option chosen in the config, it
           uses one of three algorithms (mafft linsi, mafft einsi 
           or muscle).
 Calls   : read_dir, make_dir
 Returns : 1 (can be checked in main program)
 Args    : Reference of config info (for program paths), paths to 
           fa_dir (input) and aln_dir (output) and overwrite info 
           for make_dir
 
=cut

sub align_all {
    my ( $config_info_of_REF, 
         $path_input_files,
         $path_output_files,
         $overwrite_info ) = @_;
    
    print 'Aligning AA fastas...', $n;
    
    my @fastas = &read_dir($path_input_files);
		my $total_fastas = scalar(@fastas);
		my $num = 0;
    
    # create new directory for aligned files
    my $path_out = catdir ( $path_output_files, 'aligned_fa' );
    make_dir( $overwrite_info, $path_out )
        or croak "Make_dir failed ($path_out)! $n";
    
    # program paths
    my $linsi  = ${$config_info_of_REF}{'path_to_linsi_prog'};        
    my $einsi  = ${$config_info_of_REF}{'path_to_einsi_prog'};        
    my $muscle = ${$config_info_of_REF}{'path_to_muscle_prog'}; 

    foreach my $file ( @fastas ) {
		    ++$num;
        my $in_file     = catfile ( $path_input_files, $file );
        my $out_file    = catfile ( $path_out, $file );
        if ( ${$config_info_of_REF}{'mafft_or_muscle'}    =~ m/linsi/i ) {
            die "Cannot align file $file: $!" if (system("$linsi $in_file >$out_file"));
        }
        elsif ( ${$config_info_of_REF}{'mafft_or_muscle'} =~ m/einsi/i ) {
            die "Cannot align file $file: $!" if (system("$einsi $in_file >$out_file"));
        }
        elsif ( ${$config_info_of_REF}{'mafft_or_muscle'} =~ m/muscle/i ) {
            die "Cannot align file $file: $!" if (system("$muscle -in $in_file -out $out_file"));
        }
        print "$file aligned! ($num of $total_fastas)$n";
    } 
    return 1;
}
                
##############################################################################

=head2 06. convert_all_to_stockholm
 
 Usage   : my $fastas_REF = &convert_all_to_stockholm
           ( $align_all, $path_input_files, $path_in_output_files, 
           $stockh_header_width, [\%empty_files] );
 Function: Converts fasta formatted alignments to stockholm 
           format (1. line # STOCKHOLM 1.0 / last line //). Field
           width of header is defined by input from config.
           If CYOOSH aligned the files, input of this converter 
           is taken from aln_dir/aligned_fa, else from fa_dir
 Calls   : read_dir, slurp_fasta
 Returns : Reference to all fasta files (stored in an array) from the 
           input directory (needed for compile_all_core_orthologs)
 Args    : Align_all (yes / no), paths to fa_dir (input)
           and aln_dir (in / output depending on align_all), desired 
           stockholm header width (0 - 255),
           [reference to %empty_files (needed by slurp_fasta, 
           further information there])
 
=cut

sub convert_all_to_stockholm {
    my ( $align_all, 
         $path_input_files, 
         $path_in_output_files,
         $stockh_header_width, 
         $empty_files_REF ) = @_;
    
    print 'Converting AA files to stockholm format...', $n;
            
    my $path_to_aligned;
    
    # if files are aligned, the aligned ones are stored in aln_dir/aligned_fa
    if  ( $align_all =~ m/yes/i ) {  
        my $path_aligned_fa_dir = catdir ( $path_in_output_files, 'aligned_fa' ); 
        $path_to_aligned = $path_aligned_fa_dir ;
    }
    elsif ( $align_all =~ m/no/i ){
        $path_to_aligned = $path_input_files;
    }
    
    my @fastas = &read_dir( $path_to_aligned ) 
        or croak "Could not read dir \"$path_to_aligned\": $! $n";

    foreach my $file ( @fastas ) {     
        my ( $seq_of_REF, $headers_REF ) = &slurp_fasta( $file, $empty_files_REF, $path_to_aligned );       

        # skip empty files
        next if ( scalar @{$headers_REF} == 0 );
                
        # rename output files
        $file =~ m/^(.*)(\.fa(s)?)$/;
        my $file_out  = $1.".stockh";   
        
        # open output (stockholm in aln_dir) file
        my $file_out_path = catfile ( $path_in_output_files, $file_out );
        open ( my $FH_out, '>', $file_out_path )        
            or croak "Cannot open \"$file_out_path\": $! $n";  

        my $header_format = '%-'.$stockh_header_width.'s';
        
        # print in stockholm format to output
        print {$FH_out} "# STOCKHOLM 1.0\n";    # first line of stockholm file
        
        foreach my $header ( @{$headers_REF} ) {
            printf {$FH_out} "$header_format ",$header;   # header in field (prob way to big)   
            print {$FH_out} ${$seq_of_REF}{$header},$n; # seq
        }   
        print {$FH_out} '//';                                       # last line of stockholm file
        close $FH_out;
    }
    print "Files converted to Stockholm format! $n$n";
    return \@fastas;

}

##############################################################################

=head2 07. build_all_hmms
 
 Usage   : &build_all_hmms( $hmmbuild_prog,
           $path_input_files, $path_output_files );
 Function: Builds hmm files from Stockholm files (aln_dir) 
           and stores them in hmm_dir
 Calls   : read_dir
 Returns : 1 (can be checked in main program) 
 Args    : Path to hmmbuild program, paths to aln_dir (input)
           and hmm_dir (output)
 
=cut

sub build_all_hmms {
    my ( $hmmbuild_prog, 
         $path_input_files, 
         $path_output_files ) = @_;
    
    print 'Building HMM files...', $n;
    
    my @files_to_hmm = read_dir( $path_input_files );
		my $total_files = scalar(@files_to_hmm);
    my $file_count   = 1;

    # go through all stockholm files and build hmm from it
    foreach my $file ( @files_to_hmm ) {

        next if -d $file;
        if ( $file =~ m/(.*)(\.stockh)/ ){
            my $file_out = $1.'.hmm';   # rename output file
            my $file_out_path = catfile ( $path_output_files, $file_out );
            
            my $file_in = catfile( $path_input_files, $file);
            
            # build hmm and store in hmm_dir
            croak "Could not build hmm from file \"$file\": $!" 
                if ( system( $hmmbuild_prog, $file_out_path, $file_in ) );
        }
        print $n, "... File nr. $file_count of $total_files done ...", $n;
        ++$file_count;
    }
    print "HMMs built!$n$n";
    return 1;
}

##############################################################################

=head2 08. compile_all_core_orthologs_AA
 
 Usage   : &compile_all_core_orthologs_AA( $fastas_REF, 
           $path_input_files, $path_output_files, $set_name, 
           [\%empty_files] );
 Function: Compiles all fasta files from fa_dir into one single
           file, containing all orthologous gene sequences of all 
           species and saves it in setname_HMMer3
 Calls   : slurp_fasta, read_dir (depending on M.O.)
 Returns : 1 (can be checked in main program)
 Args    : Reference to all fasta files in fa_dir, paths to fa_dir 
           (input,for slurping the files) and set_name_HMMer3 (output), 
           set name [and reference of %empty_files (needed by 
           slurp_fasta, further information there)]
 
=cut

sub compile_all_core_orthologs_AA {
    my ( $fastas_REF, 
         $path_input_files,
         $path_output_files, 
         $set_name, 
         $empty_files_REF ) = @_; 
    
    print 'Compiling core ortholog set fasta of AA sequences...', $n;
         
    # name new compilation file and open it
    my $file_out_path = catfile ( $path_output_files, $set_name.'_HMMer3.fa' );
    open ( my $FH_out,'>',$file_out_path )
        or croak "Cannot open \"$file_out_path\": $! $n";
    
    # go through each fasta and print it into compilation file
    foreach my $file ( @{$fastas_REF} ) {
        my ( $seq_of_REF, $headers_REF ) = &slurp_fasta( $file, $empty_files_REF, $path_input_files )
            or croak "Cannot slurp fasta \"$file\": $! $n"; 
        
        # skip empty files
        next if ( scalar @{$headers_REF} == 0 );

        foreach my $header ( @{$headers_REF} ) {
            print {$FH_out} $header,$n;
            # remove gaps (un-align)
            ${$seq_of_REF}{$header} =~ s/-//g;
            print {$FH_out} ${$seq_of_REF}{$header},$n; 
        }
    }
    close $FH_out;
    print "Amino acid set fasta created! $n$n";
    return 1;
}   
##############################################################################

=head2 09. compile_all_core_orthologs_NT
 
 Usage   : &compile_all_core_orthologs_NT( $path_input_files, 
           $path_in_output_files, $set_name, $path_to_exonerate,
           [\%empty_files] );
 Function: Compiles all fasta files from tmp_dir into one single
           file, containing all orthologous gene sequences of all 
           species and saves it in setname_HMMer3.
           Creates for this task a preliminary compilation file
           that contains all headers and sequences and two 
           temporary files in tmp_dir that contain always one 
           header and the corresponding sequence of AA and NT, 
           resp. and compares these two files with exonerate, 
           writes the result into the compilation file.
           Deletes tmp_dir
 Calls   : slurp_fasta, read_dir (depending on M.O.)
 Returns : 1 (can be checked in main program)
 Args    : Paths to tmp_dir (input) and set_name_HMMer3 (input 
           (set file AA), output), set name, path to exonerate 
           program [and reference of %empty_files (needed by 
           slurp_fasta, further information there)]
 
=cut

sub compile_all_core_orthologs_NT {
    my ( $path_input_files,
         $path_in_output_files, 
         $set_name, 
         $path_exonerate,
         $empty_files_REF ) = @_; 
    
    print 'Compiling core ortholog set fasta of NT sequences (exonerate)...', $n;

    # create preliminary NT set file
    my $tmp_all_NT = catfile( $path_input_files, 'tmp_all_NT.fa');
    open (my $FH_tmp_all_NT, '>', $tmp_all_NT)
        or croak "Cannot open file \"$tmp_all_NT\": $! $n";
        
    # read tmp_dir
    my @NT_files = &read_dir ( $path_input_files )
         or croak "Cannot read dir \"$path_input_files\": $! $n";
         
    # got through NT files and compile the preliminary set file     
    foreach my $file ( @NT_files ) {
        next if $file =~ m/tmp/;
        my ( $NT_seq_of_REF, $NT_headers_REF ) = &slurp_fasta( $file, $empty_files_REF, $path_input_files )
            or croak "Cannot slurp fasta \"$file\": $! $n";
        foreach my $NT_header ( @{$NT_headers_REF} ) {
            my $NT_seq = ${$NT_seq_of_REF}{$NT_header};
            $NT_seq =~ s/-//g;
            print {$FH_tmp_all_NT} $NT_header, $n, $NT_seq, $n;
        }
    }
    close $FH_tmp_all_NT;
    
    # slurp AA-compilation and pre-NT-compilation file
    my ( $AA_seq_of_REF, $AA_headers_REF ) = slurp_fasta( $set_name.'_HMMer3.fa', $empty_files_REF, $path_in_output_files )
        or croak "Cannot slurp fasta \"$set_name.'_HMMer3.fa'\": $! $n"; 
    my ( $NT_seq_of_REF, $NT_headers_REF ) = slurp_fasta( 'tmp_all_NT.fa', $empty_files_REF, $path_input_files)
        or croak "Cannot slurp fasta \"'tmp_all_NT.fa'\": $! $n"; 
        
    # name new compilation file and open it
    my $file_out_path = catfile ( $path_in_output_files, $set_name.'_HMMer3.NT.fa' );
    open ( my $FH_out,'>',$file_out_path )
        or croak "Cannot open \"$file_out_path\": $! $n";
    
    # specify parameters for system call of exonerate
    my $source_types = "-Q protein -T dna";
    #                                                                      header query id : target id
    my $exo_format   = "--showalignment no --showvulgar no --verbose 0 --ryo '>%qi (AA) : %ti (DNA)\n%tas'";    
    
    # print each header / seq of AA / NT to temp files, then exonerate
    foreach my $AA_header ( @{$AA_headers_REF} ) {
        foreach my $NT_header ( @{$NT_headers_REF} ) {
            if ( $AA_header =~ m/\Q$NT_header\E/i ) {
                
                # create two temporary files (one for AA, one for NT)
                my $tmp_AA = catfile ( $path_input_files, 'tmp_AA.fa');
                open (my $FH_tmp_AA, '>', $tmp_AA)
                    or croak "Cannot open file \"$tmp_AA\": $! $n";
                my $tmp_NT = catfile ( $path_input_files, 'tmp_NT.fa');
                open (my $FH_tmp_NT, '>', $tmp_NT)
                    or croak "Cannot open file \"$tmp_NT\": $! $n";
                    
                # print header + sequence in tmp_AA.fa / tmp_NT.fa
                print {$FH_tmp_AA} $AA_header, $n, ${$AA_seq_of_REF}{$AA_header}, $n;
                print {$FH_tmp_NT} $NT_header, $n, ${$NT_seq_of_REF}{$NT_header}, $n;
                
                close $FH_tmp_AA; 
                close $FH_tmp_NT;
                
                # compare both files with exonerate, write result to NT_compilation file
                croak "Could not compare $tmp_AA and $tmp_NT: $! $n" 
                    if ( system( "$path_exonerate $tmp_AA $tmp_NT $source_types $exo_format >>$file_out_path"));
                
                # empty files for next pair
                unlink $tmp_AA;
                unlink $tmp_NT;
                last; 
            }
        }
    }    
    # close filehandle, delete tmp_dir
    close $FH_out;
    print "Nucleotide set fasta created! $n$n";
    remove_tree( $path_input_files );
    return 1;
}

##############################################################################

=head2 10. prepare_blast_db
 
 Usage   : &prepare_blast_db( $config_taxon_info_of_REF,
           $path_input_files, $path_output_files, 
           [\%empty_files] );
 Function: Compiles the original protein sequences of the 
           orthologous genes of each species separately in one file
           which is saved in a new, species-specific directory within 
           blast_dir. These files are needed to build a blast databank.
 Calls   : read_dir, make_dir, slurp_fasta
 Returns : 1 (can be checked in main program)
 Args    : Reference of config taxon info, paths to original protein 
           sequences (input) and blast_dir (output), overwrite info 
           (yes /no),[reference of %empty_files (needed by slurp_fasta, 
           further information there)]
 
=cut

sub prepare_blast_db {
    my ( $config_taxon_info_of_REF,
         $path_input_files, 
         $path_output_files,
         $overwrite_info, 
         $empty_files_REF ) = @_;
    
    print 'Preparing files for makeblastdb...', $n;
    
    # get original sequence files   
    my @files = &read_dir( $path_input_files );
    
		#mp just lemme see 
		my @taxlist;
		foreach my $key (keys %$config_taxon_info_of_REF) {
			push(@taxlist, $_) and last for (split(',', $$config_taxon_info_of_REF{$key}));
		}
		#mp subset
		my @oldfiles = @files;
		@files = ();
		foreach my $file (@oldfiles) {
			push(@files, $file) if grep( {$file =~ /$_/} @taxlist);
		}

    # got through files and find protein sequences
    foreach my $file ( @files ) {   
				#mp dangerous indeed, wtf is this supposed to mean? 
				#mp if the file name does not contain 'proteins'? that may very well be the case.
				#mp commented out due to naivity
        #next if $file !~ m/proteins/; #---------DANGEROUS?
        
        my $new_dir         = '';
        my $abbr_version    = '';
        
        # go through taxa to find species names and version numbers corresponding to $file
        foreach my $taxon_abbr ( keys %{$config_taxon_info_of_REF} ) {      
            my @taxon_info = split ( ',', ${$config_taxon_info_of_REF}{$taxon_abbr} );
						#mp dangerous indeed, see above. 
						#mp added case insensitivity (at least)
            if ($file =~ m/$taxon_info[0]/i) { #full name----------DANGEROUS 
								print "Found proteome file $file for " . $taxon_info[0] . "\n";	#mp
                $abbr_version = $taxon_info[1].'_'.$taxon_info[2]; # abbr_version
                
                # create new dir for prot seq, named after taxon and its version
                $new_dir = catdir( $path_output_files, $abbr_version );
                make_dir( $overwrite_info, $new_dir )
                    or croak "Make_dir failed ($new_dir)! $n";
                last;
            }
        }

        # get headers and seqs of this file (no newlines)
        my ( $seq_of_REF, $headers_REF ) = &slurp_fasta( $file, $empty_files_REF, 
            $path_input_files );
        
        # skip empty files
        next if ( scalar @{$headers_REF} == 0 ) ;
                    
        # open the output file to print
        my $file_out_path = catfile ( $new_dir, $abbr_version.'_prot.fa' );                                                                                                                                 
        open ( my $FH_out,'>',$file_out_path )
            or croak "Cannot open \"$file_out_path\": $! $n";
                    
        # and print the whole thing into the new file               
        foreach my $header ( @{$headers_REF} ) {
            print {$FH_out} $header,$n;     
            print {$FH_out} ${$seq_of_REF}{$header},$n; # seq
        }
        close $FH_out;
        print "$abbr_version: done$n";          
    }
    print "Prepared files for making blastdb! $n$n";
    return 1;
}

##############################################################################

=head2 11. make_blast_db
 
 Usage   : &make_blast_db( $make_blast_db_prog, 
           $path_input_files );
 Function: Creates a blast databank for each of the
           "reference" protein files stored in the individual
           directories within blast_dir, saves it in the same 
           directory
 Calls   : read_dir
 Returns : 1 (can be checked in main program)
 Args    : Path to makeblastdb-prog, path to blast_dir (input)
 
=cut

sub make_blast_db {
    my ( $make_blast_db_prog, 
         $path_input_files ) = @_;
    
    print 'Making blast databanks...', $n;
    
    my @reference_dirs = &read_dir( $path_input_files );
    
    foreach my $ref_dir ( @reference_dirs ) {
        my @ref_files = &read_dir ( catdir( $path_input_files, $ref_dir ) );
        croak "Abnormous number of files in $ref_dir $n" if scalar @ref_files != 1;
        
        my $ref_file          = shift @ref_files;
        my $ref_file_path_in  = catfile( $path_input_files, $ref_dir, $ref_file );
        $ref_file             =~ m/^(.*)(_prot)(.fa)$/;
        my $ref_file_out      = $1.$2;  
        my $ref_file_path_out = catfile( $path_input_files, $ref_dir, $ref_file_out );
        
        croak "Could not create a blast databse from $ref_file: $! $n" 
            if ( system( "$make_blast_db_prog -in $ref_file_path_in -out $ref_file_path_out -title $ref_dir -dbtype prot" ) ) ;
    }
    print "Blast database created! $n$n";
    return 1;
} 

##############################################################################

=head2 12. slurp_fasta
 
 Usage   : my ( $seq_of_REF, $headers_REF ) = 
           &slurp_fasta( $file, [$empty_files_REF], $path_to_file);
 Function: Reads a fasta file and saves headers and sequences.
           Sequences are modified:
               - all whitespece deleted
               - all uppercase
               - translate every U (selenocystein) to X
           [Empty files are skipped, name and path are stored in 
           %empty_files so that they can be printed to the screen 
           when the rest of the program is done]
 Calls   : slurp_file
 Returns : Hash (header => sequence), array (all headers in
           original order)
 Args    : File to slurp, [reference of %empty_files] and path
           to file
 
=cut

# reject RNA, translate DNA (?)------------------------------------------------------ translate DNA!
# DNA CHECK: length (seq s/N//) -> 50% ATGC---------------------------------------------------------!!!!

sub slurp_fasta {
    my ( $file, 
         $empty_files_REF, 
         $path_to_file ) = @_; 

    if ( -z $file ) {   # if file is empty
        print "$n Skipping file \"$file\" (empty!)$n$n";
        ${$empty_files_REF}{$file}=$path_to_file;
        last;
    }
    my $path_file = catfile( $path_to_file, $file);
    
    # Read file
    my @lines = slurp_file( $path_file );
    chomp @lines;

    # Process file
    my ( $header, @headers, %sequence_of );
    
    foreach my $line ( @lines ) {
        if ( $line =~ /^(>.*)$/ ) {
            $header = $1;
            croak "Found two sequences with the same header: $header" 
                if $sequence_of{$header};
            push @headers, $header;
        }
        else {
            # Remove white space--------------------------------------------------------------------------in one line?
            $line =~ s/\s*//g;
            # Format sequence (all uppercase)
            $line =~ s/.*/\U$&/g;
            # translate every U (AA selenocystein) to X (cannot exclude RNA)---------------------------------- RNA?
            $line =~ s/U/X/g;
            # Add sequence
            $sequence_of{$header} .= $line;
        }
    }
    # Return fasta file content as hash reference
    return \%sequence_of, \@headers;
}

##############################################################################

=head2 13. slurp_file
 
 Usage   : my @lines = slurp_file( $file);
 Function: Read the entire file content, converts it
           to UNIX-style line breaks and returns all lines
           in an array
 Calls   : -
 Returns : Array (all lines of the file)
 Args    : File ( with path )
 
=cut

sub slurp_file {
    my $file = shift @_; 

    # Open filehandle
    open ( my $FILE, '<', $file )
        or croak "Couldn't open \"$file\": $!";

    # Read in entire file content at once 
    my $file_content = do { local $/; <$FILE> };

    # Close filehandle
    close $FILE
        or croak "Could't close \"$file\": $!";

    # Convert to unix-style line breaks
    $file_content =~ s/\r\n?/\n/g;

    # Split file content on line breaks
    my @file_lines = split ( '\n', $file_content );

    return @file_lines;

}

##############################################################################

=head2 14. read_dir
 
 Usage   : my @files = read_dir( $path )
 Function: Reads all file and directory names
           in a directory, hides system files (start with .)
 Calls   : -
 Returns : Array (all file and directory names)
 Args    : Path to directory
 
=cut

sub read_dir {
    my $path = shift @_; 

    # Open directory handle
    opendir ( my $dir, $path ) or 
        croak "Couldn't find path \"$path\": $!";

    # Read file names
    my @files = readdir( $dir ) or
        croak "Couldn't read directory \"$path\": $!";

    # Close directory handle
    closedir ( $dir ) or
        croak "Couldn't close directory \"$path\": $!";

    # Filter hidden system files out
    @files = grep {! /^\./ } @files;                                                    

    return @files;

}
##############################################################################

=head2 15. [save_config_in_set]
 
 Usage   : &save_config_in_set( $path_to_config, 
           $path_into_HMMer3 );
 Function: As the CYOOSH config file is priorily
           not saved within the just build set, it is nice to store it 
           there (setname_HMMer3) for later lookup purposes
 Calls   : - 
 Returns : 1 (can be checked in main program /calling subroutine) 
 Args    : Paths to config and set_name_HMMer3
 
=cut

sub save_config_in_set {
    my ( $path_to_config, 
            $path_HMMer3 ) = @_; 
    
    copy( $path_to_config, $path_HMMer3 ) or die "Copy of config failed: $! $n";
    print "Copied set file! $n";
    return 1;
}

##############################################################################

=head2 16. [print_empty_files]
 
 Usage   : &print_empty_files(\%empty_files) 
           if scalar (keys %empty_files) != 0;
 Function: Prints the names and paths of empty and
           therefore skipped files to the screen if there
           is any information stored in %empty_files
 Calls   : -
 Returns : 1 (can be checked in main program)
 Args    : Reference of %empty_files
 
=cut

sub print_empty_files {
    my $empty_files_REF = shift @_;
    
    print $n,"EMPTY / SKIPPED FILES: $n";
    
    while ( my ( $file, $path )  = each %{$empty_files_REF}) {
        print "$file : $path $n";
    }
    return 1;
}

##############################################################################

=head1 AUTHOR

Jeanne Wilbrandt - jeanne.wilbrandt@uni-bonn.de

=cut

1;
