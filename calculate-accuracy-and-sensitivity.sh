#!/bin/bash

# Copyright 2016, Malte Petersen <mptrsen@uni-bonn.de>
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

echo "Binary classification statistics calculator"
echo "Written in 2016 by Malte Petersen"

if [ $# != 4 ]; then
	echo "USAGE: $0 TOTAL_POPULATION MAX_POSSIBLE_TRUE_POSITIVES POSITIVES FALSE_POSITIVES"
	exit 1
fi

TOTAL_POPULATION=$1
MAX_POSSIBLE_TRUE_POSITIVES=$2
POSITIVES=$3
FALSE_POSITIVES=$4
TRUE_POSITIVES=$(( $POSITIVES - $FALSE_POSITIVES ))
FALSE_NEGATIVES=$(( $MAX_POSSIBLE_TRUE_POSITIVES - $TRUE_POSITIVES ))
TRUE_NEGATIVES=$(( $TOTAL_POPULATION - $FALSE_POSITIVES - $TRUE_POSITIVES - $FALSE_NEGATIVES ))

echo
echo "Selected $POSITIVES ($FALSE_POSITIVES false positives)"
echo "out of $MAX_POSSIBLE_TRUE_POSITIVES from population of $TOTAL_POPULATION"
echo
echo "True positives: " $TRUE_POSITIVES
echo "False positives:" $FALSE_POSITIVES
echo "True negatives: " $TRUE_NEGATIVES
echo "False negatives:" $FALSE_NEGATIVES
echo

bc <<END
scale=5
accuracy    = ( $TRUE_POSITIVES + $TRUE_NEGATIVES ) / $TOTAL_POPULATION
sensitivity = $TRUE_POSITIVES / ( $TRUE_POSITIVES + $FALSE_NEGATIVES )
specificity = $TRUE_NEGATIVES / ( $TRUE_NEGATIVES + $FALSE_POSITIVES )
precision   = $TRUE_POSITIVES / ( $TRUE_POSITIVES + $FALSE_POSITIVES )
print "Accuracy:    ", accuracy, "\n"
print "Sensitivity: ", sensitivity, "\n"
print "Specificity: ", specificity, "\n"
print "Precision:   ", precision, "\n"
END

echo
