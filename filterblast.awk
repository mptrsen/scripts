#!/usr/bin/awk
# filter a BLAST result file in format 7 (tab-delimited, standard)
# the fields are as follows:
# $1        $2          $3      $4          $5    $6         $7        $8      $9        $10     $11     $12
# query id, subject id, %ident, aln length, mism, gap opens, q. start, q. end, s. start, s. end, evalue, bit score


# get the first header, skip all following
/^#/ {
	if (have_header) { next }
	print
	if (/^# Fields/) { have_header = 1 }
	next
}

ident  = $3
eval   = $11
len    = $4

	# are query or target reversed?
	if ($7 < $8) {
		qstart  = $7;
		qend = $8;
		q_revsd = 0;
	} else {
		qstart  = $8;
		qend = $7;
		q_revsd = 1;
	}
	if ($9 < $10) {
		sstart  = $9;
		send = $10;
		s_revsd = 0;
	} else {
		sstart  = $10;
		send = $9;
		s_revsd = 1;
	}

	# skip all where query overlaps target, in either direction
	if    ( q_revsd && qend   <= send   && qstart >= sstart ) { next }
	elsif ( s_revsd && qstart <= sstart && qend   >= send   ) { next }
	elsif (            qstart <= send   && qend   >= sstart ) { next }

# print where identity > 97% and eval < 1e-3 and len >= 100
if ( ident > 97 && eval < 0.001 && len >= 100 ) {print}

if ( NR % 100000 == 0 ) { print "seen " NR " rows" > "/dev/stderr" }
