#!/bin/bash

# Copyright 2018, Malte Petersen <mptrsen@uni-bonn.de>
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

# Transpose a table, i.e. turn columns into lines, lines into columns.

if [[ $# -ne 1 ]]; then echo "Usage: $0 tablefile"; exit 1; fi

numc=$(awk -F "\t" '{ print NF; exit }' $1)

for ((i=1; i<=$numc; i++)); do
	cut -f $i $1 | paste -s
done
