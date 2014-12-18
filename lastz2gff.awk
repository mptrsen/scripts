#!/usr/bin/awk
BEGIN { OFS = "\t" }
/^#/ { next }
{
	strand = $3 == $8 ? "+" : "-"
	split($12, identity, "/")
	e = ( identity[2] - identity[1] ) / identity[2]
	print $2, "pals", "hit", $5, $6, $1, strand, ".", sprintf("Target %s %s %s ; maxe %f", $7, $10, $11, e)
}

