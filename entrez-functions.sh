#!/bin/bash

# Copyright 2019, Malte Petersen <mptrsen@uni-bonn.de>
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

baseurl='https://eutils.ncbi.nlm.nih.gov/entrez/eutils'

function esearch {
	db=${1}
	shift
	IFS='+'
	term="${*}"
	url="$baseurl/esearch.fcgi?db=${db}&term=${term}&rettype=count&retmode=json" 
	echo "## Search URL: ${url}"
	curl -s "${url}"
}

function efetch {
	db=${1}
	shift
	IFS=','
	ids="${*}"
	url="$baseurl/efetch.fcgi?db=${db}&rettype=fasta&retmode=text&id=${ids}"
	echo "## Search URL: ${url}"
	curl -s "${url}"
}

function striptags {
	sed -e 's/<[^>]\+>//g'
}
