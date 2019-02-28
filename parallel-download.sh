#!/bin/bash

USAGE="nohup bash $0 DATATABLE &"

if [ $# -ne 1 ]; then
	echo "Usage: $USAGE"
	echo ""
	echo "DATATABLE must have 3 whitespace-separated columns: HOST, USERNAME, PASSWORD"
	echo ""
	echo "Error: file name required"
	exit 1
fi

PREFIX="/var/data/graduateschool/data/.store/gbr"

while read HOST USER PASS; do

	NOW=$(date +%Y-%m-%dT%H:%M:%S)
	echo "$NOW launched download script: $HOST $USER $PASS" >> $PREFIX/download.status
	/bin/bash /var/data/graduateschool/tools/get-data-from-bgi.sh $HOST $USER $PASS $PREFIX &

done < $1
