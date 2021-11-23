#!/usr/bin/python

import os
import sys
import json
import re
from pathlib import Path

def main(json_file, mp3_dir):
    p = Path(mp3_dir).glob("*.mp3")
    files = [ x for x in p if x.suffix == ".mp3" ]
    with open(json_file) as f:
        data   = json.load(f)
        for k, v in data.items():
            if isinstance(v, list):
                for j in v:
                    print(j["title"], j["playlist_index"])

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
