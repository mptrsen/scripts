#!/bin/bash

# create a project directory structure, create a conda environment, and initialise a git repository.

set -o pipefail
set -o nounset
set -e

if [[ $# -ne 1 ]]; then
	echo "Usage: $0 new_project_name"
	exit 1
fi

newname="$1"

echo '## Creating directory structure'

mkdir -p "$newname"/{data/{raw,clean},results/figures,code,doc/paper,workflow/{envs,rules},scratch,config}

touch "$newname/workflow/Snakefile"

echo 'Describe the content of this directory here' > "$newname"/README.md

cat << "EOF" > "$newname"/report.Rmd
---
title: $newname
author: $(whoami | sed -e 's/^\([a-z]\)/\u\1/')
date: "`r Sys.Date()`"
output:
	html_document:
		toc: true
---
EOF

echo '## Initialising git repository'
git init "$newname"
cd "$newname"
git add workflow/Snakefile report.Rmd README.md
git commit -a -m "Initial commit"
cd - > /dev/null
echo

echo '## Creating conda environment'
conda create --yes --quiet --prefix "$newname"/code/conda
echo

echo "## Done. Created new project directory in '$newname':"
tree "$newname"
