#!/usr/bin/perl
use strict;
use warnings;
use DBI;
use DBD::mysql;
use Seqload::Fasta;
use Seqload::Mysql;
use Benchmark;

my $db       = 'forage';
my $dbserver = 'localhost';
my $dbuser   = 'mpetersen';
my $dbpwd    = 'mpetersen';
my $table    = 'ests';
my $id_col   = 'id';
my $date_col = 'date';
my $hdr_col  = 'hdr';
my $seq_col  = 'seq';
my %duplet   = ();	# to store seq data on the fly

#--------------------------------------------------
# setup the MySQL module
#-------------------------------------------------- 
Seqload::Mysql->set_table($table);
Seqload::Mysql->set_hdr_col($hdr_col);
Seqload::Mysql->set_seq_col($seq_col);

#--------------------------------------------------
# connect to database
#-------------------------------------------------- 
my $dbh = DBI->connect("dbi:mysql:$db:$dbserver", $dbuser, $dbpwd);

#--------------------------------------------------
# create database structure if not present
#-------------------------------------------------- 
my $query = "CREATE TABLE IF NOT EXISTS $table ( 
	`$id_col` INT(255) NOT NULL PRIMARY KEY AUTO_INCREMENT,
	`$date_col` INT(10) UNSIGNED,
	`$hdr_col` VARCHAR(255) NOT NULL,
	`$seq_col` VARCHAR(65000) DEFAULT NULL)";
my $sql = $dbh->prepare($query);
$sql->execute();

#--------------------------------------------------
# clear database
#-------------------------------------------------- 
$query = "DELETE FROM $table";
$sql = $dbh->prepare($query);
$sql->execute();


#--------------------------------------------------
# prepare insertion query
#-------------------------------------------------- 
$query = "INSERT INTO $table ($date_col, $hdr_col, $seq_col) VALUES (?, ?, ?)";
$sql = $dbh->prepare($query);

#--------------------------------------------------
# insert stuff into database
#-------------------------------------------------- 
my $file = Seqload::Fasta->open($ARGV[0]);
my $timestamp = time();
while (my ($hdr, $seq) = $file->next) {
	$timestamp = time();
	$sql->execute($timestamp, $hdr, $seq);
}
$file->close;

#--------------------------------------------------
# close connection
#-------------------------------------------------- 
$dbh->disconnect;

exit;

timethese(1000, {
	'mysql' => sub {
			my $newdbh = Seqload::Mysql->open($db, $dbserver, $dbuser, $dbpwd);
			while (my ($hdr, $seq) = $newdbh->next) {
				my $line = sprintf(">%s\n%s\n", $hdr, $seq);
			}
			$newdbh->close;
		},
	'fasta' => sub {
			my $sequences = Seqload::Fasta->open($ARGV[0]);
			while (my ($hdr, $seq) = $sequences->next) {
				my $line = sprintf(">%s\n%s\n", $hdr, $seq);
			}
			$sequences->close;
		}
	}
);
