#!/usr/bin/awk
# filter a BLAST result file in format 7 (tab-delimited, non-standard, see below)
# the fields are as follows:
# $1  query id
# $2  query length
# $3  subject id
# $4  subject length
# $5  percent identity
# $6  alignment length
# $7  mismatches
# $8  gap openings
# $9  query start
# $10 query end
# $11 subject start
# $12 subject end
# $13 e-value
# $14 bit score

# get the first header, skip all following
/^#/ {
	if (have_header) { next }
	if (/^# Query/)  { next } # don't need the query line
	print
	if (/^# Fields/) { have_header = 1 }
	next
}

{
	ident  = $3
	eval   = $11
	len    = $4

	# query and target on the same sequence?
	if ($1 == $2) {
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

		# skip all where query and target are on the same sequence and overlap in either direction
		if      ( q_revsd && qend   <= send   && qstart >= sstart ) { next }
		else if ( s_revsd && qstart <= sstart && qend   >= send   ) { next }
		else if (            qstart <= send   && qend   >= sstart ) { next }
	}

	# print where identity > 97% and eval < 1e-3 and len >= 100
	if ( ident > 97 && eval < 0.001 && len >= 100 ) { print }

	if ( NR % 500000 == 0 ) { print "seen " NR " rows" > "/dev/stderr" }
}
