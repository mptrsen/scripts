#!/usr/bin/perl

use strict;
use warnings;
use File::Spec::Functions;
use File::Basename;
use Getopt::Long;
use Tie::File;

=head1 NAME Output - This module summarizes the HAMSTR data and can align the sequences for each gene

=head1 SYNOPSIS

This module reads in the HAMSTR output and summarizes it for each gene in one file.

It also counts the number of internal stop codons if you do not remove them from the sequences.

Optional it aligns the amino acid sequences afterwards with Mafft and the nucleotide sequences with Pal2Nal.

Use: output.pl -id /User/HAMSTR_directory/ -align (optional) -ow (overwrites summary folder, by default disabled) -rem_stop_codons (removes stop codons in the sequences, by default disabled)

	# Create directories with summary results
	&check_summary_directory( $summary_directory, $overwrite_value );
	
	# Read all directories and files in input directory into an array
	my @dir = &read_dir( $input_directory, { 'hide' => 1 } ); 
	
	# Save each line of the inputfile in the outpufile
	&move_fasta_file( $input_file, $output_file );
	
	# Get header and sequence of last entry in file
	my ( $header, $sequence ) = &get_last_entry_of_fasta_file( $inputfile );
				
	# Append last sequence of current file to corresponding file in hamstr_summary
	&append_entry_to_fasta_file( $outputfile, $header, $sequence );

	# Align all amino acid sequences
	my $ref_aligned_files = &align_aa_sequences( $outputdirectory, $options{ 'align' } );
	
	# Make files which contain only the amino acid sequences and not the coreorthologs
	my ( $ref_nt, $ref_aa_files_without ) = &make_aa_files_without_coreorthologs( $ref_aligned_files, $outputdirectory );
	
	# Remove Stop-Codons from nt-sequences
	my $ref_filtered_nt = &remove_stop_codons( $ref_nt, catdir( $options{ 'id' }, $nt_sum_dir ) );
	
	# Align cDNA sequences with Pal2Nal
	&use_pal2nal( $ref_aa_files_without, $ref_filtered_nt, $outputdir_nt, $outputdir );
	
=cut

# Set default options
my $ow = 0;
my $align = 0;
my $rem_stop_codons = 0;
my %options = ( 'ow' => \$ow, 'align' => \$align, 'rem_stop_codons' => \$rem_stop_codons );

# Get options from command line
# id = inputdirectory, sd = summarydirectory, align = aligning files with Mafft, 
# ow = overwrite summary directories rem_stop_codons = removes stop codons from the sequences
GetOptions( \%options, 'id=s', 'align', 'ow', 'rem_stop_codons' );

# Check if input directory is provided
die "You have to provide an input directory!\n" 
   ."Optional: You can align the summary sequences with Mafft (-align). "
   ."It is by default disabled.\n"
   ."You can remove the stop codons in the sequences with -rem_stop_codons. "
   ."It is by default disabled.\n"
   ."You can allow overwriting of the summary directories with -ow. It is by default disabled "
   ."and the program aborts if it is not allowed to overwrite the content of these directories "
   ."if they exist and are not empty.\n" 
   if ( !exists $options{ 'id' } );

# Names for summary directories
my $aa_sum_dir = 'aa_summarized';
my $nt_sum_dir = 'nt_summarized';

# Create directories with summary results
&check_summary_directory( catdir( $options{ 'id' }, $aa_sum_dir ), $ow );
&check_summary_directory( catdir( $options{ 'id' }, $nt_sum_dir ), $ow );

# Get directories with relevant HAMSTR output
print "Reading input directories.\n";

# Read all directories and files in input directory into an array
my @dir = &read_dir( $options{ 'id' }, { 'hide' => 1 } ); 

# Remove files from directory list
my @filtered_dir = &remove( \@dir, qr/\.fa$/ );

# Get only files
my @species_names = grep { m/.fa$/i } @dir;

# Count the number of different genes which are processed
my $number_of_genes_total = 0;
my $stop_codons_all = 0;
my $stop_codons_statistics_species = 
	catfile( $options{ 'id' }, $aa_sum_dir, 'stop_codons_statistics_species.txt' );
open ( my $FH_codon, '>', $stop_codons_statistics_species ) 
	or die "Couldn't open file \"$stop_codons_statistics_species\": $!\n" 
	if ( $rem_stop_codons == 0 );
my %count_of_stop_codons_all;

# Process each species
foreach my $species_name ( @species_names ) {

	# Process files of each species directory
	foreach my $dir ( @filtered_dir ) {
		my %count_of_stop_codons;
		$species_name =~ m/(\w+)\.fa$/i;
		if ( $dir =~ m/^$1.+/i ) {
			
			# Print current species name on screen
			$species_name =~ m/(\w+)\.fa$/i;
			print "Process species $1\n";
			
			# Get all files from the species directory
			my @items = &read_dir( catfile( $options{ 'id' }, $dir ), { 'hide' => 1 } );
			my $aa;
			my $nt;
			foreach my $item ( @items ) {
				if ( $item =~ m/aa/i ){
					$aa = $item;
				}
				elsif ( $item =~ m/nt/i ) {
					$nt = $item;
				}
			}
			
			# Get all file names except system files
			my @aa_file_names = &read_dir( catdir( $options{ 'id' }, $dir, $aa ), {'hide' => 1} );
			my @nt_file_names = &read_dir( catdir( $options{ 'id' }, $dir, $nt ), {'hide' => 1} );
			
			# Retain only non-cds file names
			my @filtered_nt_file_names = &remove( \@nt_file_names, qr/cds/ );
			my $stop_codons = 0;
			
			# Process all aa files of current taxon
			foreach my $file_name ( @aa_file_names ) {
	
				# Check if it is a fasta-file, if not exit program
				&is_this_a_fasta_file( $file_name );
		
				# Name of the summary file
				my $summary_filename_aa;
				$file_name =~ m/^(.+)(\.aa\.fa)$/i;
				$summary_filename_aa = $1.'.summarized_with_coreorthologs'.$2;
							
				# Full path for input, output and outputfile without coreorthologs
				my $input_file  	 = catfile( $options{ 'id' }, $dir, $aa, $file_name             );
				my $output_file_with = catfile( $options{ 'id' }, $aa_sum_dir, $summary_filename_aa );
		
				# Gene does not exist in hamstr_summary		
				# File does not exist
				if ( ! -e "$output_file_with" ) {
				
					# Save each line of the inputfile in the outpufile
					$stop_codons = &move_fasta_file( $input_file, $output_file_with, $rem_stop_codons );
					++$number_of_genes_total;
					
					# Count stop codons
					$stop_codons_all += $stop_codons if ( $rem_stop_codons == 0 );
					$count_of_stop_codons{ $stop_codons } += 1 if ( $rem_stop_codons == 0 );
					$count_of_stop_codons_all{ $stop_codons } += 1 if ( $rem_stop_codons == 0 );
				}

				# Gene does exist in hamstr_summary
				else {
		
					# Get header and sequence of last entry in file
					my ( $header, $sequence ) = &get_last_entry_of_fasta_file( $input_file, $rem_stop_codons );
					
					# Count stop codons
					if ( $rem_stop_codons == 0 ) {
						my $codons += ( $sequence =~ s/\*/\*/gi );
						if ( $sequence =~ m/^\*/i ) {
							--$codons;
						}
						elsif ( $sequence =~ m/\*$/i ){
							--$codons;
						}
						$stop_codons += $codons;
						$stop_codons_all += $codons;
						$count_of_stop_codons{ $stop_codons } += 1;
						$count_of_stop_codons_all{ $stop_codons } += 1;
					}
					
					# Or remove them
					else {
						$sequence =~ s/\*//gi;
					}
					
					# Append last sequence of current file to corresponding file in hamstr_summary
					&append_entry_to_fasta_file( $output_file_with, $header, $sequence );
				}
			}
			# Print the number of internal stop codons for this species in a file
			if ( $rem_stop_codons == 0 ) {
				$species_name =~ m/(\w+)\.fa/i;
				print { $FH_codon } 'Species name: ', $1, "\t", 'Number of internal stop codons: ', $stop_codons, "\n";
				my @sorted_keys = sort keys %count_of_stop_codons;
				foreach my $key ( @sorted_keys ) {
					print { $FH_codon } "Sequences with $key internal stop codon(s): ", $count_of_stop_codons{ $key }, "\n";
				}
			}
			
			# If it is a nt file
			foreach my $nt_file_name ( @filtered_nt_file_names ) {
				
				# Check if it is a fasta-file, if not exit program
				&is_this_a_fasta_file( $nt_file_name );
			
				# Name of summary file
				$nt_file_name =~ m/^(.*)(\.nt\.fa)$/i;
				my $summary_filename_nt = $1.'.summarized_without_coreorthologs'.$2;
			
				# Full path for input and outputfile
				my $input_file  		= catfile( $options{ 'id' }, $dir, $nt, $nt_file_name );
				my $output_file_without = catfile( $options{ 'id' }, $nt_sum_dir, $summary_filename_nt );
				
				# Get header and sequence of last entry in file
				my ( $header, $sequence ) = &get_last_entry_of_fasta_file( $input_file );
				
				# Remove stop codons from sequence if option rem_stop_codons is provided
				$sequence = &remove_stop_codons( $sequence ) if ( $rem_stop_codons );	
				
				# Append last sequence of current file to corresponding file in hamstr_summary
				&append_entry_to_fasta_file( $output_file_without, $header, $sequence );
			}
			print "This directory is empty or contains only files which can not be used!\n" 
				if ( scalar @aa_file_names == 0 );
			print "Number of processed genes for this species: ", scalar @aa_file_names, "\n" 
				if ( scalar @aa_file_names );
			print "This species has $stop_codons internal stop codon(s).\n" if ( $rem_stop_codons == 0 );
		}
	}
}

close $FH_codon if ( $rem_stop_codons == 0 );

# Count '*' in aa-sequences
&count_stop_codons( catdir( $options{ 'id' }, $aa_sum_dir ) ) if ( $rem_stop_codons == 0 );	

# Make statistic file for all stop codons
my $stop_codons_statistics_all;
if ( $rem_stop_codons == 0) {

	# Make statisti file
	$stop_codons_statistics_all = catfile( $options{ 'id' }, $aa_sum_dir, 'stop_codon_statistics_all.txt' );
	open ( my $FH_stop_all, '>', $stop_codons_statistics_all ) or die "Couldn't open file \"$stop_codons_statistics_all\": $!\n";
	
	# Print total number of internal stop codons
	print { $FH_stop_all } 'Number of internal stop codons: ', $stop_codons_all, "\n";
	
	# Sort keys (lowest number first) and print them with their sum in the file
	my @sorted_keys_all = sort keys %count_of_stop_codons_all;

	foreach my $key ( @sorted_keys_all ) {
		print { $FH_stop_all } "Sequences with $key internal stop codon(s): ", $count_of_stop_codons_all{ $key }, "\n";
	}
}

my $hamstr_dir = dirname ( $options{ 'id' } ); 

# Make nt-files with coreorthologs
&get_coreorthologs_nt( $options{ 'id' }, $aa_sum_dir, $nt_sum_dir, $hamstr_dir, $filtered_dir[1] );

# Align sequences
if ( $align ) {

	# Align aa-sequences with Mafft
	my $ref_aligned_files = &align_aa_sequences( catdir( $options{ 'id' }, $aa_sum_dir ), $rem_stop_codons );

	# Make aa-files without coreorthologs
	my ( $ref_nt, $ref_aa_files_without ) = 
		&make_aa_files_without_coreorthologs( $ref_aligned_files, catdir( $options{ 'id' }, $aa_sum_dir ), catdir( $options{ 'id' }, $nt_sum_dir ) );

	# Align nt-files wit Pal2Nal using the aa-files without coreorthologs
	&use_pal2nal( $ref_aa_files_without, $ref_nt, catdir( $options{ 'id' }, $nt_sum_dir ), catdir( $options{ 'id' }, $aa_sum_dir ) );
}

print "Summary completed!\n";
print "Number of processed taxons: ", scalar @species_names, "\n";
print "Number of different genes: $number_of_genes_total\n";
print "Number of internal stop codons im all species: $stop_codons_all\n" if ( $rem_stop_codons == 0 );

exit;

	
=head1 APPENDIX

The rest of the documentation details each of the subroutines in alphabetical order.

=cut

#########Subroutines#########
	
=head2 align aa sequences

Title: align_aa_sequences

Usage: my @aligned_files = &align_aa_sequences( $directory, $alignment_program );

Function: Iterates through all files in the directory and aligns the sequences with Mafft or Muscle if they are amino acids and the file is a fasta-file

Returns: A reference to an array of the aligned files

Args: The path to the directory as a string and the alignment program as a string

=cut

##############################
#align_aa_sequences
##############################
# Aligns aa sequences after summarizing them for each gene with mafft or muscle
sub align_aa_sequences {

	# Unpack @_
	my $output = shift @_;
	
	# Get all files in the output directory
	my @files = &read_dir( $output, { 'hide' => 1 } );
	my @aligned_files;

	# Iterate through each file and align it
	foreach my $file ( @files ) {
		my $file_path = catfile( $output, $file );
		next if ( $file =~ m/.+\.aln$/i );
		next if ( $file =~ m/\.nt/i );
		next if ( $file =~ m/\.txt$/i );
		
		$file =~ m/(.+)(\.(fa){0,1}(faa){0,1}(fas){0,1}(fasta){0,1}(ffn){0,1}(fna){0,1}(fst){0,1}(frn){0,1}(mfpfa){0,1}(seq){0,1})$/i;
		my $file_aligned = catfile( $output, ( $1.'.aln' ) );
		
		die "Can not align file \"$file\": $!\n" if (system( "mafft --preservecase $file_path > $file_aligned" ) );
		push ( @aligned_files, $file_aligned );
	}
	return \@aligned_files;
}

=head2 append entry to fasta file

Title: append_entry_to_fasta_file

Usage: &append_entry_to_fasta_file( $outputdirectory, $summary_filename_aa, $header, $sequence );

Function: Prints the last header and the last concatenated sequence into an existing file

Returns: -

Args: Path to the outputdirectory as a string, the name of the file where it should be saved and the header and sequence which are printed in the file

=cut

##############################
#append_entry_to_fasta_file
##############################
# Appends one header and one sequence to an existing file
sub append_entry_to_fasta_file {

	# Unpack @_
	my ( $file, $header, $sequence ) = @_;
	
	# Open Filehandle
	open ( my $FH, '>>', $file ) or die "Couldn't open file \"$file\": $!\n";
	
	# Print header and sequence in file
	print {$FH} $header, "\n", $sequence, "\n";
	
	# Close filehandle
	close $FH;
}

=head2 check summary directory

Title: check_summary_directory

Usage: &check_summary_directory( $outputdirectory, $overwriting );

Function: Checks if the summary directory exists. If it exists and is not empty it deletes the content if overwriting is enabled otherwise the program is aborted. If the directory does not exist it is created.

Returns: -

Args: Path to the summary directory as a string and value for the overwriting option

=cut

##############################
#check_summary_directory
##############################
# Checks if the summary directory exists and deletes the content if overwriting is enabled
sub check_summary_directory {
	
	# Unpack @_
	my $sd = shift @_;
	my $ow = shift @_;
	
	if ( -e $sd ) {
	
		# If exists, check whether or not it contains files
		my @sum_dir = &read_dir( $sd, {'hide' => 1 } );
	
		# If it contains files, ask whether they should be deleted or exit program
		if ( @sum_dir )  {
			if ( $ow ) {
				&remove_files( $sd );
				print "Content of the directory has been deleted!\n";
			}
			else {
				die "Directory \"$sd\" is not empty! Please choose an alternative directory or delete the content.\n";
			}
		}
	}
	
	# If directory does not exist, create it
	else {
		mkdir $sd;
	}
}

=head2 count stop codons

Title: count_stop_codons

Usage: &count_stop_codons( catdir( $options{ 'id' }, $aa_sum_dir ) )

Function: Counts the internal stop codons of the aa-files

Returns: -

Args: Path to the aa-summary-directory as a string

=cut

##############################
#count_stop_codons
##############################
# Counts the stop codons in the aa-sequences
sub count_stop_codons{
	
	# Unpack @_
	my $path = shift @_;
	
	# Get all aa files in the directory
	my @aa_files = &read_dir( $path, { 'hide' => 1 } );
	
	# Make statistic file
	my $stop_codon_file = catfile( $path, 'stop_codons_statistics_genes.txt' );
	open ( my $FH2, '>', $stop_codon_file ) or die "Couldn't open file \"$stop_codon_file\": $!\n";

	# print Genname and number of internal stop codons for each gen in the file
	print { $FH2 } 'Genname', "\t", 'Number of internal stop codons', "\n";
	
	foreach my $file ( @aa_files ) {
		$file =~ m/(\d+)\.\w+\.aa\.fa/i;
		open ( my $FH, '<', catfile( $path, $file ) ) or die "Couldn't open file \"$file\": $!\n";
		my $count = 0;
		while ( my $line = <$FH> ) {
			if ( $line !~ m/^>/i ) {
				$count += ( $line =~ s/\*/\*/g );
				if ( $line =~ m/^\*/ ) {
					--$count;
				}
				elsif ( $line =~ m/\*$/ ) {
					--$count;
				}
			}
		}
		print { $FH2 } $1, "\t", $count, "\n";
	}
}

=head2 get coreorthologs nt

Title: get_coreorthologs_nt

Usage: &get_coreorthologs_nt( $options{ 'id' }, $aa_sum_dir, $nt_sum_dir, $hamstr_dir, $filtered_dir[0] );

Functions: Creates a file which contains the nt-coreorthologs and the corresponding sequences from the nt-files

Return: -

Args: The path to the inputdirectory, the names of the summary directories and the name of the hamstr directory as strings as well as on species directory as a string

=cut

##############################
#get_coreorthologs_nt
##############################
# Makes summarized files which cotain the nt-coreorthologs and the nt-sequences from the species
sub get_coreorthologs_nt{
	
	# Unpack @_
	my $path   	   	 = shift @_;
	my $aa_dir 	   	 = shift @_;
	my $nt_dir	   	 = shift @_;
	my $hamstr_dir 	 = shift @_;
	my $filtered_dir = shift @_;
	
	my $index;
	my @core_nt_files;
	
	# Get name of the coreortholog set
	$filtered_dir =~ m/\w+(insecta_.+)/i;
	
	my $core_nt_path = catfile( $hamstr_dir, 'core_orthologs', $1, $1.'.nt.fa' );
	
	# Get all lines form the coreortholog set file in an array
	tie  @core_nt_files, 'Tie::File', $core_nt_path or die "Couldn't open file \"$core_nt_path\": $!\n";
	
	# Get all files from the summary directories
	my @aa_files = &read_dir( catdir( $path, $aa_dir ), { 'hide' => 1 } );
	my @nt_files = &read_dir( catdir( $path, $nt_dir ), { 'hide' => 1 } );
	
	# Iterate through all nt-files
	foreach my $nt_file ( @nt_files ) {
	
		# Get genname and filename for the new summary file with coreorthologs
		$nt_file =~ m/(\d+).+/i;
		my $nt_file_with = $1.'.summarized with_coreorthologs.nt.fa';
		open ( my $FH2, '>>', catfile( $path, $nt_dir, $nt_file_with ) ) or die "Couldn't open file \"$nt_file_with\": $!\n";
		
		# Iterate through all aa-files to find the equivalent of the nt-file
		foreach my $aa_file ( @aa_files ) {
			open (my $FH_aa, '<', catfile( $path, $aa_dir, $aa_file ) ) or die "Couldn't open file \"$aa_file\": $!\n";
			$nt_file =~ m/(\d+)\.\w+\.nt\.fa/i;
			if ( $aa_file =~ m/^$1.+/i ) {
				
				while ( my $line = <$FH_aa> ) {
					chomp $line;
					$index = 0;
					if ( $line =~ m/^>/ ) {
						
						# Find the matching header in the nt-coreorthologs an print it with its sequence in the new file
						foreach my $item ( @core_nt_files ) {
						
							if ( $line eq $item ) {
								chomp $item;
								print { $FH2 } $item, "\n";
								++ $index;								
								if ( $core_nt_files[$index] !~ m/^>/ ) {
									chomp $core_nt_files[$index];
									print { $FH2 } $core_nt_files[$index];
									++$index;
								}
								print { $FH2 } "\n";
								next;
							}
							else {
								++$index;
							}
						}
					}
				}
			}
			close $FH_aa;
		}
		
		# Print content from the nt-file without core orthologs in the new file
		open ( my $FH3, '<', catfile( $path, $nt_dir, $nt_file ) ) or die "Couldn't open file \"$nt_file\": $!\n";
		while ( my $line2 = <$FH3> ) {
			chomp $line2;
			print { $FH2 } $line2, "\n";
		}
		close $FH2;
		close $FH3;
	}
}

=head2 get last entry of fasta file

Title: get_last_entry_of_fasta_file

Usage: my ( $header, $sequence ) = &get_last_entry_of_fasta_file( $file_name, $inputdirectory, $current_directory );

Function: Iterates through all lines of a file and returns the last header and the last concatenated sequence as strings

Returns: $header, $sequence

Args: The file name as a string, the inputdirectory as a string and the current workingdirectory as a string

=cut

############################
#get_last_entry_of_fasta_file
############################
# Returns the last header and the last sequence of a fasta-file (each as a string)
sub get_last_entry_of_fasta_file {

	# Unpack @_
	my $file = shift @_;
	#my $rem_stop_codons = shift @_;
	
	# Open filenhandle
	open ( my $FH, '<', $file ) or die "Couldn't open file \"$file\": $!\n";
	
	# Make scalar variables for the header and the sequence
	my $header   = '';
	my $sequence = '';
	
	# Checks each line if it is a header or a sequence and stores the line in the corresponding string
	# Each new header/sequence overwrites the last one
	while ( my $line = <$FH> ) {
		chomp $line;
		
		# Check if it is a header, if so store it in $header
		# Store concatenated sequence in $sequence
		if ( $line =~ m/^>/ ) {
			$header = $line;
			$sequence = '';
		}
		
		# Check if it is a sequence, if so concatenate them
		else {
			$sequence .= $line;
		}
	}
	
	# Close filehandle
	close $FH;
	
	# Return last header and last sequence as strings
	return $header, $sequence;
}

=head2 is this a fasta file

Title: is_this_a_fasta_file

Usage: &is_this_a_fasta_file( $file_name );

Function: Checks if the provided file is in the fasta format and exits the program if it is not

Returns: -

Args: Filename as a string

=cut

############################
#is_this_a_fasta_file
############################
# Checks if the input directories contain only fasta files. Stopps if a file does not ends with .fa or .fas
sub is_this_a_fasta_file {

	# Upack @_
	my $file = shift @_;
	
	# Dies if file has not the right suffix
	die "$file is not a fasta file!\n" if ( $file !~ m/^.+\.(fa){0,1}(faa){0,1}(fas){0,1}(fasta){0,1}(ffn){0,1}(fna){0,1}(fst){0,1}(frn){0,1}(mfpfa){0,1}(seq){0,1}$/i ); 
}

=head2 make aa files without coreorthologs

Title: make_aa_files_without_coreorthologs

Usage: &make_aa_files_without_coreorthologs( \$ref_to_aligned_aa_files, $directory );

Function: Saves aa sequences without coreorthologs in a new file after comparing them with the sequences in the cdna files

Returns: -

Args: Reference to an array with the aligned aa-sequences with coreorthologs as a string and path to the directory as a string

=cut

##############################
#make_aa_files_without_coreorthologs
##############################
sub make_aa_files_without_coreorthologs {
	
	# Unpack @_
	my $ref_aligned_files = shift @_;
	my $aa_dir 			  = shift @_;
	my $nt_dir			  = shift @_;
	
	# Get all files
	my @nt_files_all = &read_dir( $nt_dir, { 'hide' => 1 } );
	my @nt_files = grep { m/.+_without_.+/i } @nt_files_all;
	my @aligned_aa_without;
	
	# Iterate through all nt files
	foreach my $file ( @nt_files ) {
	
		$file =~ m/^(\d+)\.\w+\.nt\..+$/i;
		my $genname = $1;
		my $file_out = $genname.'.summarized_without_coreorthologs.aa.aln';
		
		open ( my $FH, '<', catfile( $nt_dir, $file ) ) or die "Couldn't open file \"$file\": $!\n";
		
		# Iterate through each line of the file and save it in the outputfile
		my $header = '';
		while ( my $line = <$FH> ) {
			chomp $line;
			if ( $line =~ m/^>/ ) {
				$header = $line;
			
				foreach my $file2 ( @{ $ref_aligned_files } ) {
		    		   	    
					if ( $file2 =~ m/$genname.+\.aln$/i ) {
						
						open ( my $FH_in,  '<',  $file2     ) or die "Couldn't open file \"$file2\": $!\n";
						open ( my $FH_out, '>>', catfile( $aa_dir, $file_out ) ) or die "Coulnd't open file \"$file_out\": $!\n";
						my $first_line = 1;
						my $header2 = '';
						my $sequence = '';
						while ( my $line2 = <$FH_in> ) {
							chomp $line2;
					
							if ( $line2 =~ m/^>/ ) {
								if ( $first_line ){
									$header2 = $line2;
									--$first_line;
								}
								else {
									if ( $header2 eq $header ) {
										print { $FH_out } $header2, "\n", $sequence, "\n";
									}
									$header2 = $line2;
									$sequence = '';
								}
							}
							else {
								$sequence .= $line2;
							}
						}
						print { $FH_out } $header2, "\n", $sequence, "\n" if ( $header2 eq $header );
										
						close $FH_in;
						close $FH_out;
					}
				}
			}
		}
		push ( @aligned_aa_without, $file_out );
	}
	return \@nt_files, \@aligned_aa_without;
}

=head2 move fasta file

Title: move_fasta_file

Usage: &move_fasta_file( $input_file, $output_file );

Function: Prints each header and concatenated sequence of a file in a new not existing file

Returns: -

Args: Inputfile as a string and outputfile as a string

=cut

##############################
#move_fasta_file
##############################
# Gets each line of the inputfile and saves it in another file in the summary directory
sub move_fasta_file {

	# Unpack @_
	my $inputfile  		= shift @_;
	my $outputfile  	= shift @_;
	my $rem_stop_codons = shift @_;
	
	# Open filehandles for both files
	open ( my $FH , '<', $inputfile  ) or die "Couldn't open file \"$inputfile\": $!\n" ;
	open ( my $FH2, '>', $outputfile ) or die "Couldn't open file \"$outputfile\": $!\n";
	
	# Iterate through each line of the file and save it in the outputfile
	my $first_line = 1;
	my $sequence   = '';
	while ( my $line = <$FH> ) {
		chomp $line;
		if ( $line =~ m/^>/ ) {
			if ( $first_line ) {
				print { $FH2 } $line, "\n";
				--$first_line;
			}
			else {
				$sequence =~ s/\*//gi if ( $rem_stop_codons );
				print { $FH2 } $sequence, "\n";
				print { $FH2 } $line, "\n";
				$sequence = '';
			}
		}
		else {
			$sequence .= $line;
		}
	}
	
	# Count stop codons
	my $stop_codons = 0;
	if ( $rem_stop_codons == 0 ) {
		$stop_codons += ( $sequence =~ s/\*/\*/gi );
		if ( $sequence =~ m/^\*/i ) {
			--$stop_codons;
		}
		elsif ( $sequence =~ m/\*$/i ){
			--$stop_codons;
		}
	}
	$sequence =~ s/\*//gi if ( $rem_stop_codons );
	print { $FH2 } $sequence, "\n";
	
	# Close filehandles
	close $FH;
	close $FH2;
	
	return $stop_codons;
}

=head2 read dir

Title: read_dir

Usage: my @dir = &read_dir( $inputdirectory, { 'hide' => 1 } );

Functions: Reads the content of a directory in an array. If the argument 'hide' true system files are omitted

Returns: @dir

Args: The inputdirectory as a string and optional a hash for hiding system files

=cut

##############################
#read_dir
##############################
# Reads all files in a directory
sub read_dir {
		
	# Unpack @_
	my ( $path, $arg_ref ) = @_; 

	# Defaults
	my %DEFAULT_OF = ( 'hide' => 1,  # 1: hide system files; 0: don't 
	);

	# Check provided arguments
	die 'Missing or superfluous arguments'        if @_ < 1  || @_ > 2;
	die 'Option(s) not passed via anonymous hash' if @_ == 2 && ref $arg_ref ne 'HASH';

	foreach my $provided_options ( keys %{ $arg_ref } ) {
		die 'Unknown option(s)' if !exists $DEFAULT_OF{ $provided_options }; 
	}

	# Set defaults
	#          If option given...            use option             else default
	my $hide = exists $arg_ref->{'hide'}  ?  $arg_ref->{'hide'}  :  $DEFAULT_OF{'hide'};

	# Open directory handle
	opendir ( my $dir, $path ) or 
		die "Couldn't find path \"$path\": $!";

	# Read file names
	my @files = readdir( $dir ) or
		die "Couldn't read directory \"$path\": $!";

	# Close directory handle
	closedir ( $dir ) or
		die "Couldn't close directory \"$path\": $!";

	# Filter hidden system files out
	if ( $hide ) {
		@files = grep {! /^\./ } @files;
	}

	# Return file names
	return @files;
}

=head2 remove

Title: remove

Usage: my @filtered_array = &remove( \@array, qr/expression/i );

Function: Stores all items which do not fit the expression into an array

Returns: @filtered_array

Args: An array which has to be filtered and an expression as a filter

=cut

############################
#remove
############################
# Remove files from an array for processing which fit the pattern
sub remove {

	# Unpack @_
	my ( $items_ref, $regex ) = @_;
	
	# Checks each item if it matches the regex and stores only those in the array which don't
	my @filtered_items = grep { ! m/$regex/i } @{ $items_ref };
	
	# Returns filtered list as an array
	return @filtered_items;
}

=head2 remove files

Title: remove_files

Usage: &remove_files( $directory );

Function: Removes all content from a directory

Returns: -

Args: The directory as a string

=cut

#############################
#remove_files
#############################
# Deletes files from the summary directory if it is not empty and the user wants to delete the content
sub remove_files{

	# Unpack @_
	my ( $path, $dir ) = @_;
	
	# Read all files of the directory and store them in an array
	my @files = &read_dir( catdir( $path, $dir ) );
	
	# Delete each file in the array from the directory or warn if it could not be deleted
	foreach my $file ( @files ) {
		unlink catfile( $path, $dir, $file ) or warn "Failed to delete file \"$file\": $!\n";
	}
}

=head2 remove stop codons

Title: remove_stop_codons

Usage: $sequence = &remove_stop_codons( $sequence );

Function: Removes the stop codons from the nt-sequences

Returns: The sequence without the stop codons

Args: The complete sequence as a string

=cut

##############################
#remove_stop_codons
##############################
# Removes the stop codons in the nt-sequences
sub remove_stop_codons {

	# Unpack @_
	my $seq = shift @_;
	
	# Make new sequence without stop codons
	my $new_seq = '';
	for ( my $position = 0; $position < length $seq; $position += 3 ) {
		my $triplet = substr( $seq, $position, 3 );
		$new_seq .= $triplet if ( $triplet !~ m/TAA|TAG|TGA/i );
	}
	return $new_seq;
}

=head2 use pal2nal

Title: use_pal2nal

Usage: &use_pal2nal( $ref_aa_files_without, $ref_filtered_cdna, $options{ 'sd' } );

Function: Aligns cdna sequences with Pal2Nal

Returns: -

Args: Reference to the list of amino acids files as string, reference to the list of cdna files as a string and the directory path as a string.

=cut

##############################
#use_pal2nal
##############################
# Aligns the nt-sequences with Pal2Nal
sub use_pal2nal {

	# Unpack @_
	my $ref_to_aa_files = shift @_;
	my $ref_to_nt_files = shift @_;
	my $nt_path			= shift @_;
	my $aa_path			= shift @_;
	
	# Iterate trough all aa-files
	foreach my $file ( @{ $ref_to_aa_files } ) {
	
		# Iterate through all nt-files
		foreach my $file2 ( @{ $ref_to_nt_files } ) {
			$file =~ m/(\d+)\.\w+\.aa\.aln$/i;
			
			# Align the nt-file which is coresponding to the aa-file
			if ( $file2 =~ m/$1/i ) {
				$file2 =~ m/^(\d+\.\w+)(\.nt)\.fa$/i;
				my $file3 	   = $1.$2.'.aln';
				my $aafile     = catfile( $aa_path, $file  );
				my $ntfile     = catfile( $nt_path, $file2 );
				my $outputfile = catfile( $nt_path, $file3 );
				die "Can not use Pal2Nal: $!\n" if ( system( "pal2nal.pl $aafile $ntfile > $outputfile" ) );
			}
		}
	}
}
