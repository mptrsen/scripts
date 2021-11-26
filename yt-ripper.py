#!/usr/bin/python

import os
import sys
import json
import subprocess
import re
from pathlib import Path

def main(url):
    def tag_file(mp3_file, json_file):
        # extract data from JSON
        with open(json_file) as f:
            data   = json.load(f)
        song   = data["title"]
        # fallback cascade for "artist"
        artist = ""
        try: data["artist"]
        except KeyError: data["artist"] = None
        try: data["creator"]
        except KeyError: data["creator"] = None
        try: data["uploader"]
        except KeyError: data["uploader"] = None
        if data["artist"] is not None:
            artist = data["artist"]
        elif data["creator"] is not None:
            artist = data["creator"]
        elif data["uploader"] is not None:
            artist = data["uploader"]
        else: sys.exit(1)

        # fallback cascade for "release_year"
        year = ""
        try: data["release_year"]
        except KeyError: data["release_year"] = None
        if data["release_year"] is not None:
            year   = str(data["release_year"])
        else:
            year = str(data["upload_date"])[0:4]

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

    def cleanup_title(filename):
        """
        This function removes special character (sequences) from the title to produce a safe file name.
        youtube-dl does the same, so we need to reproduce the same pattern.
        """
        clean_tit = re.sub("\?",  "",    filename)  # question marks are removed by youtube-dl
        clean_tit = re.sub("\|+", "_",   clean_tit) # pipes replaced with _ by youtube-dl
        clean_tit = re.sub(": ",  " - ", clean_tit) # youtube-dl doesn't like :
        clean_tit = re.sub('"',   "'",   clean_tit) # double quotes to single quotes
        return clean_tit
        
    def download_from_json(json_file):
        ytdl_cmd = [ "youtube-dl",
                    "--extract-audio",
                    "--audio-format", "mp3",
                    "--audio-quality", "192k",
                    "--retries", "5",
                    "--continue",
                    "--output", "%(playlist_index)02d_%(title)s_%(id)s.%(ext)s" ]
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

    # Get the playlist JSON first to get the playlist title
    print("Downloading playlist info for {url}".format(url = url))
    playlist_data = download_playlist_json(url)

    album = playlist_data["title"]
    album = re.sub("[^\w]", "_", album)
    print("# Playlist title: {album}\n".format(album = album))

    # Create new directory, dump the playlist JSON, and change there
    p = Path(album)
    p.mkdir(parents = True, exist_ok = True)
    with open(Path(p, "playlist.info.json"), "w") as json_file:
        json.dump(playlist_data, json_file)
    os.chdir(p)

    revisit = list()
    playlist_length = len(playlist_data["entries"])
    c = 0
    # Download each playlist json entry individually. This is more robust and
    # flexible than downloading the entire playlist because youtube-dl can not
    # skip existing videos.
    for entry in playlist_data["entries"]:
        c = c + 1
        clean_title = cleanup_title(entry["title"])
        file_stem = "{index:02d}_{title}_{id}".format(index = entry["playlist_index"], title = clean_title, id = entry["id"])
        json_file = file_stem + ".info.json"
        mp3_file  = file_stem + ".mp3"
        if not Path(json_file).exists():
            with open(Path(json_file), "w") as f:
                json.dump(entry, f)
        if Path(mp3_file).exists():
            print("## mp3 file for \'{title}\' exists ({file}), skipping download".format(title = entry["title"], file = mp3_file))
            next
        else: # necessary file do not exist, re-create JSON, download and tag
            print("Downloading ({n} of {n_all}): {title}".format(title = entry["title"], n = c, n_all = playlist_length))
            download_from_json(json_file)
        print("Tagging: {mp3}".format(mp3 = mp3_file))
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
    print("Done downloading playlist: {album}".format(album = album))
    sys.exit()


####### Main starts here #############################

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Error: expected exactly one URL")
        print("Usage: {program} youtube_URL".format(program = str(sys.argv[0])))
        sys.exit(1)
    url = sys.argv[1]
    main(url)
