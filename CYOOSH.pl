#!/usr/bin/perl 

=head1  CYOOSH - CREATE YOUR OWN ORTHOLOG SET for HAMSTR 	(v 1.2)	

This program helps you to set up your own set of primer taxa 
(and their core-ortholog groups), which you can use for the HAMSTR program. 

The CYOOSH config tells you which information is needed for proper running,
and gives you the possibility to adjust the program to your needs.

It is therefore essential that you read it!

Note that RNA input is not allowed and that this program is designed to
run on UNIX systems. The Core Ortholog Set is based on amino acid sequences
that you provide. Additionally, this program compiles a set file containing
all corresponding nucleotide sequences (exonerate). This is the only purpose
that nucleotide sequences have here.

=head1 SYNOPSIS

Not (yet) executable, so you need to type this command to the prompt:

perl CYOOSH.pl /path/to/config/CYOOSH_set_config.txt

=cut

use strict;
use warnings;

use Carp;
use lib '.';
use CYOOSH_Utilities ('read_CYOOSH_config', 'create_HAMSTR_input_tree', 
                      'mk_dir', 'adjust_all_fa_headers', 'align_all', 
                      'convert_all_to_stockholm', 'build_all_hmms', 
                      'compile_all_core_orthologs_AA', 'compile_all_core_orthologs_NT', 
                      'prepare_blast_db', 'make_blast_db', 'slurp_fasta', 'slurp_file', 'read_dir', 
                      'save_config_in_set', 'print_empty_files', 'remove_dir');

=head1 WORKFLOW

=cut

my $n = "\n";
my %empty_files;

=head2 Read CYOOSH Config

Retrieves all needed information on paths, options and taxa from the config
and returns it sorted into two hashes. Also returns the path to the config
for further usage.

=cut

my ( $config_info_of_REF, 
     $config_taxon_info_of_REF, 
	 $path_to_config ) 
        = &read_CYOOSH_config
            or die "Failed in execution of sub 'read_CYOOSH_config'! $n $n";

=head2 Create directory tree

Tree structure matches the requirements of HAMSTR. Retrieves the
information needed for this step from the hash that stores the config data
(not on taxa, the other one).

=cut

my ($path_into_REF) 
        = &create_HAMSTR_input_tree( ${$config_info_of_REF}{'path'}, 
                                     ${$config_info_of_REF}{'set_name'},
                                     ${$config_info_of_REF}{'overwrite'} )
            or die "Failed in execution of sub 'create_HAMSTR_input_tree'! $n $n";

=head2 Header adjustment (Amino acid sequences) (partially optional)

Goes through all fastas (provided, amino acid sequences) and renames all 
headers by inserting the corresponding ortholog gene name (retrieved from fasta 
file name) and the OGS version (retrieved from taxon info of config) if this 
option ('adjust_all_aa_headers') is specified with 'yes' in the config. 

Else, it will save the fastas within the new set anyway (fa_dir), but not insert 
the OGS version. This is necessary for further processing.
Skips empty files (see slurp_fasta in CYOOSH_Utilities.pm).

=cut

        &adjust_all_fa_headers( 'AA',
                                $config_taxon_info_of_REF, 
                                $config_info_of_REF, 
                                ${$config_info_of_REF}{'path_to_orig_AA'},  
                                ${$path_into_REF}{'fa_dir'}, 
                                \%empty_files)
            or die "Failed in execution of sub 'adjust_all_fa_headers'! $n $n";
            
=head2 Header adjustment (Nucleotide sequences) (partially optional)

Goes through all fastas (provided, nucleotide sequences) and renames all 
headers by inserting the corresponding ortholog gene name (retrieved from fasta 
file name) and the OGS version (retrieved from taxon info of config) if this 
option ('adjust_all_nt_headers') is specified with 'yes' in the config. 

Else, it will save the fastas within the new set anyway (tmp_dir), but not insert 
the OGS version. This is necessary for further processing.
Skips empty files (see slurp_fasta in CYOOSH_Utilities.pm).

=cut

        &adjust_all_fa_headers( 'NT',
                                $config_taxon_info_of_REF, 
                                $config_info_of_REF, 
                                ${$config_info_of_REF}{'path_to_orig_NT'},  
                                ${$path_into_REF}{'tmp_dir'}, 
                                \%empty_files)
            or die "Failed in execution of sub 'adjust_all_fa_headers'! $n $n";

=head2 Align sequences (optional)

In this step, all fastas are aligned if 'align_all' is specified with 'yes' in the 
config. You can choose between three algorithms (mafft linsi, mafft einsi and
muscle). 

=cut

if  (${$config_info_of_REF}{'align_all'} =~ m/yes/i) { 
        &align_all ( $config_info_of_REF,
                     ${$path_into_REF}{'fa_dir'},
                     ${$path_into_REF}{'aln_dir'},
                     ${$config_info_of_REF}{'overwrite'}) 
            or die "Failed in execution of sub 'read_CYOOSH_config'! $n $n";
}
	
=head2 Convert to stockholm format

Converts all aligned (either by this program or already before) fastas (with 
adjusted headers (or not)) to stockholm format, which is needed to use
hmmbuild.
This format separates header and sequence in fields of arbitrary width, 
but the field width of the header should not exceed 255 characters. In
the config you can define the field width (min. 50 is recommended).

Stockholm format:
        # STOCKHOLM 1.0         -> first line
        >header     sequence
        //                      -> last line

=cut

my $fastas_REF 
        = &convert_all_to_stockholm( ${$config_info_of_REF}{'align_all'},
                                     ${$path_into_REF}{'fa_dir'}, 
                                     ${$path_into_REF}{'aln_dir'},
                                     ${$config_info_of_REF}{'stockh_header_width'}, 
                                      \%empty_files )
            or die "Failed in execution of sub 'convert_all_to_stockholm'! $n $n";

=head2 Build hmms

Builds hmms for each individual core-ortholog (based on the stockholm files)
in HMMer3 format.

=cut

        &build_all_hmms( ${$config_info_of_REF}{'path_to_hmmbuild_prog'},
                         ${$path_into_REF}{'aln_dir'}, 
                         ${$path_into_REF}{'hmm_dir'} )
            or die "Failed in execution of sub 'build_all_hmms'! $n $n";

=head2 Compilation of core-orthologs (Amino acid sequence)

Writes all sequences of all core-ortholog genes (from fa_dir) 
into one file (fasta format) in set_name_HMMer3.

=cut

        &compile_all_core_orthologs_AA( $fastas_REF, 
                                        ${$path_into_REF}{'fa_dir'}, 
                                        ${$path_into_REF}{'_HMMer3'}, 
                                        ${$config_info_of_REF}{'set_name'}, 
                                        \%empty_files )
            or die "Failed in execution of sub 'compile_all_core_orthologs_AA'! $n $n";
            
=head2 Compilation of core-orthologs (Nucleotid sequence)

Writes all sequences of all core-ortholog genes (from tmp_dir) 
into one file (fasta format) in set_name_HMMer3. To do this, 
every header and every sequence of all nuc-fasta-files are
compared with every header / sequence of the compiled amino
acid file (exonerate).
Deletes tmp_dir.

=cut

#       &compile_all_core_orthologs_NT( ${$path_into_REF}{'tmp_dir'}, 
#                                       ${$path_into_REF}{'_HMMer3'}, 
#                                       ${$config_info_of_REF}{'set_name'},
#                                       ${$config_info_of_REF}{'path_to_exonerate_prog'}, 
#                                       \%empty_files )
#           or die "Failed in execution of sub 'compile_all_core_orthologs_NT'! $n $n";

=head2 Prepare files for creating blast databanks

All species in this set will be considered by HAMSTR as reference species, so
a blast databank for each species is necessary. In this step, all originally used 
protein sequences of one species are compiled to one file and this file is
stored in a species-specific directory within blast_dir. 

=cut

        &prepare_blast_db( $config_taxon_info_of_REF,
                           ${$config_info_of_REF}{'path_to_orig_prot'}, 
                           ${$path_into_REF}{'blast_dir'},
                           ${$config_info_of_REF}{'overwrite'},
                           \%empty_files )
            or die "Failed in execution of sub 'prepare_blast_db'! $n $n";

=head2 Make blast databank

Creates a blast databank based on the files from the previous step and in the 
same (species-specific) directory.

=cut

        &make_blast_db( ${$config_info_of_REF}{'path_to_mkblastdb_prog'}, 
                        ${$path_into_REF}{'blast_dir'} )
            or die "Failed in execution of sub 'make_blast_db'! $n $n";

=head2 Save config in set (optional but recommended)

The config contains important information on the presets used to create the 
new ortholog set and it is therefore useful to save it together with the set
for lookup purposes. This is done in this step.

=cut

        &save_config_in_set( $path_to_config, 
                                ${$path_into_REF}{'_HMMer3'} )
            or die "Failed in execution of sub 'save_config_in_set'! $n $n";

# remove temporary dir
        
				&remove_dir($$path_into_REF{'tmp_dir'}) or die "Could not remove tempdir: $!\n";


=head2 Print empty files (optional)

Prints names and paths of all empty and therefore skipped files. Actually, 
something went terribly wrong before you used this program if it tells you
that files have been skipped, because empty fastas are very unusual. 
If you are sure that you have no empty files you can omit this step.

=cut

if ( scalar ( keys %empty_files ) != 0 ) {
        &print_empty_files( \%empty_files ) 
            or die "Failed in execution of sub 'print_empty_files'! $n $n";
}
            

print "DONE! $n";

=head1 AUTHOR

Jeanne Wilbrandt - jeanne.wilbrandt@uni-bonn.de

=cut

