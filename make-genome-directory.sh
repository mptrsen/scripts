#!/bin/bash

# create a directory structure like this:
#
# species
# |
# ` genome
#   |-- assembly
#   `-- reads
# 
# 

set -e

if [[ $# -ne 1 ]]; then echo "Usage: $0 species_name"; exit 1; fi

mkdir -p "$1"/genome/{assembly,reads}
