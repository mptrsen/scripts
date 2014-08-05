#!/usr/bin/perl
use strict;
use warnings;
use autodie;

use DBI;
use DBD::SQLite;
use Time::HiRes;

my $database = '/home/mpetersen/orthograph/orthograph.sqlite';

my $query = <<"EOSQL";
	SELECT * FROM orthograph_taxa
EOSQL


my $dbh = DBI->connect("DBI:SQLite:$database") or die DBI::errstr;
my $sth = $dbh->prepare($query);
$sth->execute();

print join "\t", @{ $sth->{NAME} }, "\n";

my $t1 = scalar time;

while (my $row = $sth->fetchrow_arrayref()) {
	printf "%s\t", defined $_ ? $_ : 'NULL' foreach (@$row);
	print "\n";
}

my $t2 = scalar time;

printf "Fetched %d rows in %.2f seconds\n", $sth->rows(), $t2 - $t1;

$dbh->disconnect();


__END__
