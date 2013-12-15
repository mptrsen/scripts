#!/usr/bin/perl

use strict;
use warnings;
use File::Spec::Functions;
use Getopt::Long;

=head1 NAME Header back translation - a script which translates the consecutive headers of one translations table back to their original content

=head1 SYNOPSIS 

use header_back_trans.pl -trans_table /Users/trans_table.txt -inputdir /Users/inputdirectory/ -outputdir /Users/outputdirectory/

	# Get all files in inputdirectory
	my @files = &read_dir( $options{ 'inputdir' }, { 'hide' => 1 } );

	# Translate headers with the translation table
	&back_translation( $options{ 'trans_table' }, $options{ 'inputdir' }, $options{ 'outputdir' }, @files );
	
=cut
	
# Get options from commandline
# -trans_table = Path to the translation table, -inputdir = Path to the input directory, 
# -outputdir = Path to the outputdirectory
my %options;
GetOpt ( \%options, 'trans_table=s', 'inputdir=s', 'outputdir=s' );

# Check if outputdirectory differs from the inputdirectory
die "Input and outputdirectory can not be the same directory!\n" if ( $options{ 'inputdir' } eq $options{ 'outputdir' } );

# Get all files in inputdirectory
my @files = &read_dir( $options{ 'inputdir' }, { 'hide' => 1 } );

# Translate headers with the translation table
&back_translation( $options{ 'trans_table' }, $options{ 'inputdir' }, $options{ 'outputdir' }, @files );

exit;

=head1 APPENDIX

The rest of the documentation details each of the subroutines in alphabetical order.

=cut

################Subroutine(s)############

=head2 back translation

Title: back_translation

Usage: &back_translation( $options{ 'trans_table' }, $options{ 'inputdir' }, $options{ 'outputdir' }, @files );

Function: Translates the new header back into the original one with the translation table

Returns: -

Args: The translation table as a string, the inputdirectory as a string, the outputdirectory as a string and an array that contains all files

=cut

##############################
#back_translation
##############################
# Translates last part of header in original header
sub back_translation {
	
	# Unpack @_
	my $translation_table = shift @_;
	my $inputdirectory    = shift @_;
	my $outputdirectory	  = shift @_;
	my @files 			  = @_;
	
	# Get entries from the translation table as a hash with the new header as key and the old header als value
	my %old_header_of = &get_original_header( $translation_table );
	
	# Iterate through all files in the inputdirectory
	foreach my $file ( @files ){
				
		# Open filehandles
		open ( my $FH_input, '<', catfile( $inputdirectory,  $file ) ) or die "Couldn't open file \"$file\": $!\n"    ;
		open ( my $FH_out,   '>', catfile( $outputdirectory, $file ) ) or die "Couldn't open file \"$file\": $!\n";
		
		# Check if file exists in directory
		
		if ( -e catfile( $outputdirectory, $file ) ){
			print "The file \"$file\" exists in this directory.\n"
				 ."Do you want to overwrite the existing file? Press 'y' or 'n' followed by <enter>.\n"
				 ."The program aborts if you do not want to overwrite the file.\n";
			my $answer = <STDIN>;
			if ( $answer =~ m/n|no/i ){
				die "Please chose another outputdirectory or overwrite the file!\n";
			}
			else {
				last;
			}
		}
		#Iterate through all lines of the file
		my $first_header = 1;
		my $sequence = '';
		while ( my $line = <$FH_input> ){
			chomp $line;	
			# Print original header and sequence in a new file
			if ( $line =~ m/^>/ ){
				# Get new header
				$line =~ m/^(.+)\|(\d+)$/i;
				my $old_header = $old_header_of{ $2 };
				my $new_header = $1.'|'.$old_header;
				if ( $first_header ){
					print { $FH_out } $new_header, "\n";
					--$first_header;
				}
				else {
					print { $FH_out } $sequence,   "\n";
					print { $FH_out } $new_header, "\n";
					$sequence = '';
				}
			}
			# Concatenate the sequence lines of one header
			else {
				$sequence .= $line;
			}
		}
		# Print last sequence into the file
		print { $FH_out } $sequence, "\n";
		
		# Close filehandles
		close $FH_input;
		close $FH_out;
	}
}

=head2 get original header

Title: get_original_header

Usage: my %old_header_of = &get_original_header( $translation_table );

Function: Stores all new header old header pairs in a hash

Returns: A hash which contain new header old header pairs

Args: The path to the translation table as a string

=cut

##############################
#get_original_header
##############################
# Gets the original header from the translation table
sub get_original_header{
	# Unpack @_
	my $translation_table = shift @_;
	
	# Open filehandle
	open ( my $FH, '<', $translation_table ) or die "Couldn't open file \"$translation_table\": $!\n";
	
	# Store new header as key and old header as value in a hash
	my %old_header_of;
	my $first_line = 1;
	while ( my $line = <$FH> ){
		chomp $line;
		# Skip first line because it contains the species name
		if ( $first_line ){
			--$first_line;
			next;
		}
		# Split each line into the two items
		my @items = split ( "\t", $line );
		
		# Make a key value pair out of the items
		$old_header_of{ $items[0] } = $items[1];
	}
	# Close filehandles
	close $FH;
	
	# Return hash
	return %old_header_of;
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