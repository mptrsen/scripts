#!/usr/bin/python

import os
import sys
import json
import subprocess
import re
from pathlib import Path

def tag_file(mp3_file, data):
    """
    Use id3v2 to add tags to the mp3 file.
    """
    # extract data from JSON
    song   = data["title"]
    # fallback cascade for "artist"
    artist = ""
    if "artist" in data:
        artist = data["artist"]
    elif "creator" in data:
        artist = data["creator"]
    elif "uploader" in data:
        artist = data["uploader"]
    else: sys.exit(1)

    # fallback cascade for "release_year"
    year = ""
    if "release_year" in data:
        year   = str(data["release_year"])
    else:
        year = str(data["upload_date"])[0:4]

    # fallback cascade for "playlist" and "playlist_index"
    album = ""
    track = None
    if "playlist" in data:
        album  = data["playlist"]
        track  = str(data["playlist_index"])
    problems = 0
    if album  == None:
        album  = ""
        problems = problems + 1
    if artist == None:
        artist = ""
        problems = problems + 1
    if track is None:
        track  = [ ]
    else:
        track = [ "--track", track ]
    # tag
    cmd = [ "id3v2", "--artist", artist,
        "--album", album,
        "--year", year,
        "--song", song,
        mp3_file ]
    if track is not None:
        cmd[-1:-1] = track
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

def output_template(index = True):
    if index == False:
        return "%(title)s_%(id)s.%(ext)s"
    return "%(playlist_index)02d_%(title)s_%(id)s.%(ext)s"

def download_from_json(json_data, audio_format = "mp3", audio_quality = "320k", output_template = output_template() ):
    """
    Download one video from info in a JSON file, and convert it to mp3 format.
    The default output file name template is:
    "%(playlist_index)02d_%(title)s_%(id)s.%(ext)s" 
    This obviously only works completely if the video is embedded in a playlist
    """
    ytdl_cmd = [ "youtube-dl",
                "--extract-audio",
                "--audio-format", audio_format,
                "--audio-quality", audio_quality,
                "--retries", "5",
                "--continue",
                "--output", output_template ]
    json_file = Path(get_file_stem(json_data) + ".info.json")
    with open(json_file, "w") as f:
        json.dump(json_data, f)
    cmd_json = ytdl_cmd + [ "--load-info-json", json_file ]
    res = subprocess.run(cmd_json)
    if res.returncode != 0:
        sys.exit(res.returncode)
    # clean up, remove JSON file
    json_file.unlink()
    return res

def download_playlist_json(url):
    """
    Download and dump playlist JSON to a single file
    """
    cmd = [ "youtube-dl", "--dump-single-json", url ]
    res = subprocess.run(cmd, capture_output = True)
    if res.returncode != 0: # exit on error
        print("Error downloading playlist JSON")
        sys.exit(res.returncode) 
    data = json.loads(res.stdout) # read JSON on success
    return data

def get_file_stem(json_data):
    clean_title = cleanup_title(json_data["title"])
    # if part of a playlist
    if "playlist_index" in json_data and json_data["playlist_index"] is not None:
        file_stem = "{index:02d}_{title}_{id}".format(index = json_data["playlist_index"], title = clean_title, id = json_data["id"])
    # otherwise file name without index
    else:
        file_stem = "{title}_{id}".format(title = clean_title, id = json_data["id"])
    return file_stem

def download_playlist(json_data):
    album = json_data["title"]
    album = re.sub("[^\w]", "_", album)
    print("# Playlist title: {album}\n".format(album = album))

    # Create new directory, dump the playlist JSON, and change there
    p = Path(album)
    p.mkdir(parents = True, exist_ok = True)
    with open(Path(p, "playlist.info.json"), "w") as json_file:
        json.dump(json_data, json_file)
    os.chdir(p)

    revisit = list()
    playlist_length = len(json_data["entries"])
    c = 0
    # Download each playlist json entry individually. This is more robust and
    # flexible than downloading the entire playlist because youtube-dl can not
    # skip existing videos.
    for entry in json_data["entries"]:
        c = c + 1
        file_stem = get_file_stem(entry)
        json_file = Path(file_stem + ".info.json")
        mp3_file  = Path(file_stem + ".mp3")
        if mp3_file.exists():
            print("## mp3 file for \'{title}\' exists ({file}), skipping download".format(title = entry["title"], file = mp3_file))
            next
        else: # necessary file do not exist, re-create JSON, download and tag
            print("Downloading ({n} of {n_all}): {title}".format(title = entry["title"], n = c, n_all = playlist_length))
            download_from_json(entry)
        print("Tagging: {mp3}".format(mp3 = mp3_file))
        res = tag_file(mp3_file, entry)
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


def download_single_track(json_data):
    # do the same stuff, just for a single file
    mp3_file = Path(get_file_stem(json_data) + ".mp3")
    if not mp3_file.exists():
        print("Downloading {title}".format(title = json_data["title"]))
        download_from_json(json_data, output_template = output_template(index = False))
    print("Tagging: {mp3}".format(mp3 = mp3_file))
    res = tag_file(mp3_file, json_data)

def main(url):
    # Get the playlist JSON first to get the playlist title
    print("Downloading info for {url}".format(url = url))
    json_data = download_playlist_json(url)

    if "_type" in json_data and json_data["_type"] == "playlist":
        # is a playlist
        download_playlist(json_data)
    else:
        # is a single track
        download_single_track(json_data)

    sys.exit()


####### Main starts here #############################

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Error: expected exactly one URL")
        print("Usage: {program} youtube_URL".format(program = str(sys.argv[0])))
        sys.exit(1)
    url = sys.argv[1]
    main(url)
