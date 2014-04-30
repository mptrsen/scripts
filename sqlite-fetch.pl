#!/usr/bin/perl
use strict;
use warnings;
use autodie;

use DBI;
use DBD::SQLite;
use Time::HiRes;

my $database = '/home/mpetersen/orthograph/orthograph.sqlite';

my $query = <<"EOSQL";

SELECT DISTINCT
                        o_blast_9.target,
                        o_blast_9.score,
                        o_blast_9.evalue,
                        o_blast_9.start,
                        o_blast_9.end
                FROM o_hmmsearch_9
                LEFT JOIN o_blast_9
                        ON o_hmmsearch_9.id = o_blast_9.hmmsearch_id
                WHERE o_hmmsearch_9.id         IS NOT NULL
                        AND o_blast_9.hmmsearch_id   IS NOT NULL
                        AND o_hmmsearch_9.id         = 11787
                ORDER BY o_blast_9.score DESC

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
