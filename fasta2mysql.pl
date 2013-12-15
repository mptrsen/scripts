#!usr/bin/perl;
# Program to upload scaffold sequence data to MySQL database 
use warnings;
use strict;
use Carp;
use olivermysql;
use File::Temp qw/ tempfile /;
use lib '/home/malty/thesis/forage/';
use Seqload::Fasta qw(fasta2csv);

# User with upload priviliges
my $user = 'malty';

# Path to and name of input fasta file
my $path = '/home/malty/tmp';
my $csvfile = '/home/malty/tmp/fasta.csv';

# Name of database and database table
my $database = 'forage';
my $table    = 'test';

####################################################################################################
# Main program
####################################################################################################

# Open file handle for input fasta file 
my $input_filename = $ARGV[0];
open my $input_fh, '<', $input_filename
	or croak "Cannot open input file \"$input_filename\": $!";

# Create temporary file to store reformatted data
my ($tmp_file_fh, $tmp_file) = tempfile( DIR => $path, UNLINK => 1, SUFFIX => '.tmp' );


# fasta2csv

fasta2csv($input_filename, $csvfile);

exit;

my $infh = Seqload::Fasta->open($input_filename);
while (my ($hdr, $seq) = $infh->next_seq) {
	print $tmp_file_fh $hdr . ',' . $seq . "\n";
}

$infh->close;

# Close file handles
close $input_fh;
close $tmp_file_fh;

# Connect to mysql database
my $dbh = MySQL::connect({ database => $database, user => $user });

# Delete all existing entries in table
$dbh->do("DELETE FROM $table");

# Upload data
$dbh->do("LOAD DATA LOCAL INFILE '$tmp_file' INTO TABLE $table FIELDS TERMINATED BY ','");

# Disconnect from mysql database
$dbh->disconnect();

# Exit program
exit;
