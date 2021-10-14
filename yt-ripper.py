#!/usr/bin/python

import os
import sys
import json
import subprocess
import re
from pathlib import Path

def tag_file(mp3_file, json_file):
    # extract data from JSON
    with open(json_file) as f:
        data   = json.load(f)
        song   = data["title"]
        artist = data["artist"]
        year   = str(data["release_year"])
        album  = data["playlist"]
        track  = str(data["playlist_index"])
    problems = 0
    if album  == None:
        album  = ""
        problems = problems + 1
    if artist == None:
        artist = ""
        problems = problems + 1
    if track  == None:
        track  = ""
        problems = problems + 1
    # tag
    cmd = [ "id3v2", "--artist", artist,
            "--album", album,
            "--year", year,
            "--track", track,
            "--song", song,
            mp3_file ]
    res = subprocess.run(cmd)
    if res.returncode != 0:
        print("Error tagging {title}".format(title = song))
        problems = problems + 1
    return problems

def download_from_json(json_file):
    ytdl_cmd = [ "youtube-dl",
        "--extract-audio",
        "--audio-format", "mp3",
        "--audio-quality", "192k",
        "--retries", "5",
        "--continue" ]
    cmd_json = ytdl_cmd + [ "--load-info-json", json_file ]
    res = subprocess.run(cmd_json)
    if res.returncode != 0:
        sys.exit(res.returncode)

def download_playlist_json(url):
    cmd = [ "youtube-dl", "--dump-single-json", url ]
    res = subprocess.run(cmd, capture_output = True)
    if res.returncode != 0: # exit on error
        print("Error downloading playlist JSON")
        sys.exit(res.returncode) 
    data = json.loads(res.stdout) # read JSON on success
    return data

url = sys.argv[1]

# Get the playlist JSON first to get the playlist title
print("Downloading playlist info for {url}".format(url = url))
playlist_data = download_playlist_json(url)

album = playlist_data["title"]
album = re.sub("[^\w]", "_", album)
print("Playlist title: {album}".format(album = album))

# Create new directory, dump the playlist JSON, and change there
p = Path(album)
p.mkdir(parents = True, exist_ok = True)
with open(Path(p, "playlist.info.json"), "w") as json_file:
    json.dump(playlist_data, json_file)
os.chdir(p)

revisit = list()
playlist_length = len(playlist_data["entries"])
c = 0
# Download each entry individually. This is more robust than downloading the
# entire playlist because youtube-dl can not skip existing videos.
for entry in playlist_data["entries"]:
    c = c + 1
    json_file = "{title}_{id}.info.json".format(title = entry["title"], id = entry["id"])
    mp3_file  = "{title}_{id}.mp3".format(title = entry["title"], id = entry["id"])
    if Path(json_file).exists() and Path(mp3_file).exists():
        next
    else: # one of the necessary files do not exist, re-create JSON, download and tag
        with open(Path(json_file), "w") as f:
            json.dump(entry, f)
        print("Downloading {title} ({n} of {n_all})".format(title = entry["title"], n = c, n_all = playlist_length))
        download_from_json(json_file)
    print("Tagging {mp3}".format(mp3 = mp3_file))
    res = tag_file(mp3_file, json_file)
    if res != 0: revisit.append(mp3_file)
    print() # empty line for structure

if len(revisit): 
    print("# Some files had errors while tagging, please revise:")
    for f in revisit:
        print("- {f}".format(f = f)) 
        
# go back to prior working dir
os.chdir(Path(".").parent)

# Bye
sys.exit()
