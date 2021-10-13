#!/usr/bin/python

import os
import sys
import json
import subprocess
from pathlib import Path

url = sys.argv[1]
params = sys.argv[2:]

# Download entire playlist. The JSON files will be important for parsing
cmd = [ "youtube-dl",
        "--extract-audio",
        "--audio-format", "mp3",
        "--audio-quality", "192k",
        "--write-info-json",
        "{url}".format(url = url) ]
res = subprocess.run(cmd, capture_output = False)

# Work from the collected mp3 files and associated JSON info dumps
p = Path(".")
files = list(p.glob("*.mp3"))
error = 0
for mp3 in files:
    json_file = Path(mp3.stem + ".info.json")
    if not json_file.exists():
        print("No JSON for {mp3}".format(mp3 = mp3))
        error = 1
        next
    # extract data from JSON
    with open(json_file) as f:
        data   = json.load(f)
        song   = data["title"]
        artist = data["artist"]
        year   = str(data["release_year"])
        album  = data["playlist_title"]
        track  = str(data["playlist_index"])
    print("Tagging {mp3}".format(mp3 = mp3))
    cmd = [ "id3v2", "--artist", artist,
            "--album", album,
            "--year", year,
            "--track", track,
            "--song", song,
            mp3 ]
    res = subprocess.run(cmd)
    if res.returncode != 0:
        error = res.returncode
        sys.exit(error)

if error: sys.exit(error)
