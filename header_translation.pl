#!/usr/bin/perl

use strict;
use warnings;
use File::Spec::Functions;
use File::Basename;
use Getopt::Long;

=head1 NAME Header Translation - This is a script that translate the headers of one or several files into consecutive numbers.

=head1 SYNOPSIS 

This module reads in all headers in the files, replaces them with a consecutive number and makes a translation table consisting of the original header and the new header for each file.

use header_translation.pl -f /Users/file.fa or -d /Users/inputdirectory -od /Users/outputdirectory -ow (overwrite extisting files, optional, by default disabled)

	# Get original filename
	my ( $file, $outputdirectory ) = fileparse( $options{ 'f'/ 'd' } );
	
	# Make filename of the translation table and filename of the translated file	
	my ( $filename, $translation_table ) = &make_filename_translation_table( $options{ 'f'/'d' } );

=cut

# Set default value for owerwriting and make a hash for the command line options 
my $ow = 0;
my %options = ( 'ow' => \$ow );

# Get options from command line
# f = File (Path + name), d = inputdirectory, od = outputdirectory, ow = overwrite existing files
GetOptions( \%options, 'f=s', 'd=s', 'od=s', 'ow' );

# Abort programm is a single file as well a whole directory is prowided as an input
die "You have to prowide an inputfile or an directory, not both!\n" 
	if (exists $options{ 'f' } && exists $options{ 'd' } );

# Abort program if neither file or directory is provided as an input
die "You have to provide at least an inputfile or a directory to run the script!\n"
   ."E.g.: -f /Users/Desktop/testfile.fa or -d /Users/Desktop/inputdirectory\n"
   ."Optional options are: -od /Users/Desktop/outputdirectory\n"
   ."-ow Existing files with same name will be overwritten. It is by default disabled.\n"
   if (!exists $options{ 'f' } && !exists $options{ 'd' } );

# Make directory if it does not exist
if ( exists $options{ 'od' } ) {
	if ( ! -e $options{ 'od' } ) {
		mkdir $options{ 'od' };
	}
}

# Translate headers of a single file
# Input and outputdirectory are the same
if ( exists $options{ 'f' } && !exists $options{ 'od' } ) {
	# Get original filename
	my ( $file, $outputdirectory ) = fileparse( $options{ 'f' } );
	# Make filename of the translation table and filename of the translated file	
	my ( $filename, $translation_table ) = &make_filename_translation_table( $options{ 'f' } );
	
	# If overwriting files is enabled
	if ( $ow ) {
		# Translate the headers
		&translate_headers_single_file( $options{ 'f' }, $outputdirectory, $translation_table, $filename );
	}
	# If overwriting files is disabled
	else {
		# Check if the file exists
		# If it does not exist
		if ( ! -e catfile( $outputdirectory, $filename ) ) {
			# Translate the headers
			&translate_headers_single_file( $options{ 'f' }, $outputdirectory, $translation_table, $filename );
		}
		# If the file exists end program
		else {
			die "File \"$filename\" exists already!\n"
			   ."Please chose a different outputdirectory or allow overwriting!\n";
		}
	}
}
# Input and outputdirectory are different
elsif ( exists $options{ 'f' } && exists $options{ 'od' } ) {
	# Get original filename
	my ( $file ) = fileparse( $options{ 'f' } );
	# Make filename of the translation table and filename of the translated file	
	my ( $filename, $translation_table ) = &make_filename_translation_table( $options{ 'f' } );
	# If overwriting files is enabled
	if (  $ow ) {
		# Translate the headers
		&translate_headers_single_file( $options{ 'f' }, $options{ 'od' }, $translation_table, $filename );
	}
	# If overwriting files is disabled
	else {
		# Check if the file exists
		# If it does not exist
		if ( ! -e catfile( $options{ 'od' }, $filename ) ) {
			# Translate the headers
			&translate_headers_single_file( $options{ 'f' }, $options{ 'od' }, $translation_table, $filename );
		}
		# If the file exists end program
		else {
			die "File \"$filename\" exists already!\n"
			   ."Please chose a different outputdirectory or allow overwriting!\n";
		}
	}
}
# Translate a directory
elsif ( exists $options{ 'd' } && !exists $options{ 'od' } ) {

		# Read all files in the directory
		my @files = &read_dir( $options{ 'd' }, { 'hide' => 1 } );
		my @filtered_files = &remove( \@files, qr/_translat\w+\.\w+/ );
		# Translate headers of all files
		&translate_headers_directory( $options{ 'd' }, $options{ 'd' }, $ow, @filtered_files );
	
}

elsif ( exists $options{ 'd' } && exists $options{ 'od' } ) {
		
	# Read all files in the directory
	my @files = &read_dir( $options{ 'd' }, { 'hide' => 1 } );
	my @filtered_files = &remove( \@files, qr/_translat\w+\.\w+/i );

	# Translate headers of all files
	&translate_headers_directory( $options{ 'd' }, $options{ 'od' }, $ow, @filtered_files );
}

exit;

=head1 APPENDIX

The rest of the documentation details each of the subroutines in alphabetical order.

=cut

#############Subroutine(s)##############

=head2 make filename translation table

Title: make_filename_translation_table

Usage: my ( $filename, $translation_table ) = &make_filename_translation_table( $file );

Function: Creates the filename of the translation table and the filename of the translated file

Returns: The new filename as a string and the name of the translation table as a string

Args: The path to the input file

=cut

##############################
#make_filename_translation_table
##############################
# Makes the filename of the translation table and the name of the new file
sub make_filename_translation_table {

	# Unpack @_
	my $input      = shift @_;
	
	# Get filename
	my $filename = fileparse( $input );
	$filename    =~ m/^(.+)(\.(fa){0,1}(faa){0,1}(fas){0,1}(fasta){0,1}(ffn){0,1}(fna){0,1}(fst){0,1}(frn){0,1}(mfpfa){0,1}(seq){0,1})$/i;
	my $new_filename = $1.'_translated'.$2;
	
	# Make name of the translation table
	my $translation_table = $1.'_translation_table.txt';
	
	# Check if the file is a fasta file
	die "This is not a fasta file!\n" if ( $filename !~ m/^.+\.(fa){0,1}(faa){0,1}(fas){0,1}(fasta){0,1}(ffn){0,1}(fna){0,1}(fst){0,1}(frn){0,1}(mfpfa){0,1}(seq){0,1}$/i );
	
	# Return the filename and the name of the translation table as strings
	return $new_filename, $translation_table;
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

Usage: my @filtered_files = &remove( \@files, qr/_translat\w+\.\w+/ );

Function: Removes all files from the file list which contain the expression 'translat'

Returns: An array with the filtered files

Args: A reference to the array containing all files and the expression

=cut
############################
#remove
############################
# Remove all files which contain '_translat'
sub remove {

	# Unpack @_
	my ( $items_ref, $regex ) = @_;
	
	# Checks each item if it matches the regex and stores only those in the array which don't
	my @filtered_items = grep { ! m/$regex/i } @{ $items_ref };
	
	# Returns filtered list as an array
	return @filtered_items;
}

=head2 translate headers directory

Title: translate_headers_directory

Usage: &translate_headers_directory( $options{ 'd' }, $options{ 'd' }, $ow, @filtered_files );

Functions: Translates the headers of each file in the file list of the directory and creates for each file a translation table

Returns: -

Args: The inputdirectory as a string, the outputdirectry as a string, the value for overwriting files and a list of the file which will be translated as an array

=cut

#############################
#translate_headers_directory
#############################
# Iterates through the files in the directory and translates the headers
sub translate_headers_directory {
	
	# Unpack @_
	my $input  = shift @_;
	my $output = shift @_;
	my $ow 	   = shift @_;
	my @files  = @_;

	# Iterate through all files in the directory
	foreach my $file ( @files ){
		# Get name of the new file and translation table
		my ( $filename, $translation_table ) = &make_filename_translation_table( catfile( $input, $file ) );
		# If overwriting files is enabled
		if ( $ow ) {
			# Translate headers
			&translate_headers_single_file( catdir( $input, $file ), $output, $translation_table, $filename );
		}
		# If overwriting files is disabled
		else {
			# Check if file exists
			# If file does not exist
			if ( ! -e catfile( $output, $filename ) ) {
				# Translate headers
				&translate_headers_single_file( catdir( $input, $file ), $output, $translation_table, $filename );
			}
			# End program if file exists
			else {
				die "File \"$filename\" exists already!\n"
		   			."Please chose a different outputdirectory or allow overwriting!\n";
			}
		}
	}
}

=head2 translate headers single file

Title: translate_headers_single_file

Usage: &translate_headers_single_file( $options{ 'f' }, $options{ 'od' }, $translation_table, $filename );

Returns: -

Args: The inputfile as a string, the outputdirectory as a string, the name of the translation table and the new filename

=cut

#############################
#translate_headers_single_file
#############################
# Iterates through each line of a file and translates the headers
sub translate_headers_single_file {
	
	# Unpack @_
	my $file	  		  = shift @_;
	my $outputdir 		  = shift @_;
	my $translation_table = shift @_;
	my $new_file          = shift @_;
	
	# Set number of first header
	my $header_number = 1; 
	
	# Open a filehandles
	open ( my $FH,     '<', $file	   			             		  ) or die "Couldn't open file \"$file\": $!\n";
	open ( my $FH_new, '>', catfile( $outputdir, $new_file			) ) or die "Couldn't open file \"$new_file\": $!\n";
	open ( my $FH_out, '>', catfile( $outputdir, $translation_table ) ) or die "Couldn't open file \"$translation_table\": $!\n";
	
	# Iterate through all lines in the file
	my $first_header = 1;
	my $sequence = '';
	$translation_table =~ m/(.+)(_translation_table\.txt)/i;
	#Print species name into the translation table
	print { $FH_out } $1, "\n";
	while ( my $line = <$FH> ){
		chomp $line;
		if ( $line =~ m/^>(.+)$/ ){
			# Define new header
			my $original_header = $1;
			my $new_header = sprintf ( "%012d", $header_number );
			
			# Print new header + old header in the translation table
			print { $FH_out } $new_header, "\t", $original_header, "\n";
			
			# Print new header with sequence into a new file
			if ( $first_header ){
				print { $FH_new } '>', $new_header, "\n";
				--$first_header;
			}
			else {
				print { $FH_new }      $sequence,   "\n";
				print { $FH_new } '>', $new_header, "\n";
				$sequence = '';
			}
			++$header_number;
		}
		# Concatinate sequence of one header
		else {
			$sequence .= $line;
		}
	}
	# Print last sequence
	print { $FH_new } $sequence, "\n";
	
	# Close filehandles
	close $FH;
	close $FH_new;
	close $FH_out;
}