#!/usr/bin/env perl
use strict;
use warnings;

use DBI;
use DBD::mysql;
use Data::Dumper;
use Carp;

my $mysql_dbname = 'orthograph';
my $mysql_dbserver = '127.0.0.1';
my $mysql_dbuser  = 'malty';
my $mysql_dbpwd = 'malty';

my $query = "SHOW TABLES";
my $res = &mysql_get($query);

my $dbh = &mysql_dbh();

foreach my $line (@$res) {
	my $table = my $new_table = $$line[0];
	$new_table =~ s/orthograph/o/;
	my $query = "RENAME TABLE $table TO $new_table";
	$dbh->do($query);
}

$dbh->disconnect();

sub mysql_dbh {
	return DBI->connect("DBI:mysql:$mysql_dbname:$mysql_dbserver", $mysql_dbuser, $mysql_dbpwd);
}

sub mysql_get {
	my $query = shift;
	unless ($query) { croak "Usage: mysql_get(QUERY)\n" }
  # prepare anonymous array
	my $results = [ ];
  # connect and fetch stuff
	my $dbh = &mysql_dbh;
	my $sql = $dbh->prepare($query);
	$sql->execute() or die;
	while (my @result = $sql->fetchrow_array() ) {
		push(@$results, \@result);
	}
	$sql->finish();
	$dbh->disconnect; # disconnect ASAP
	return $results;
}
