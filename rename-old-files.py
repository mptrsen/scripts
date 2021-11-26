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
                for track in v:
                    #print(track["title"], track["playlist_index"])
                    clean_title = re.sub("\?", "", track["title"]) # remove ?
                    clean_title = re.sub("\|+", "_", clean_title) # replace | w _
                    new_file_name = Path(mp3_dir, "{index:02d}_{title}_{id}.{ext}".format(index = track["playlist_index"], title = clean_title, id = track["id"], ext = "mp3"))
                    old_file_name = Path(mp3_dir, "{title}_{id}.{ext}".format(title = clean_title, id = track["id"], ext = "mp3"))
                    if new_file_name.exists():
                        print("new file {file} exists, doing nothing".format(file = new_file_name))
                        next
                    elif old_file_name.exists():
                        print("old file {file} exists, renaming".format(file = old_file_name))
                        old_file_name.rename(new_file_name)
                        next
                    else:
                        print("Problem: mp3 file for '{title}' not found\nlooked for: {file}".format(title = track["title"], file = old_file_name))
if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
