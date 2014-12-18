#!/usr/bin/awk
# skip all comment lines
/^#/ { next }

# $1        $2          $3      $4          $5    $6         $7        $8      $9        $10     $11     $12
# query id, subject id, %ident, aln length, mism, gap opens, q. start, q. end, s. start, s. end, evalue, bit score

# skip all where query is identical to target
( $1 == $2 && $7 == $9 && $8 == $10 ) { next }

# skip all where query overlaps target
( $7 < $9 && $8 > $9 ) { next }

# skip all where target overlaps query
( $7 > $9 && $8 > $9 ) { next }

# print where identity > 97% and eval < 1e-3 and len >= 100
( $3 > 97 && $11 < 0.001 && $4 >= 100 ) {print}
