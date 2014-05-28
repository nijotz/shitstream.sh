[![Build Status](https://travis-ci.org/nijotz/shitstream.svg?branch=master)](https://travis-ci.org/nijotz/shitstream)
shitstream
==========

Prerequisites (client):
* mpg123

Prerequisites (server):
* sox
* curl
* youtube-dl
* mp3gain
* beets

Beets setup:
    $ mkvirtualenv shitstream
    $ pip install beets       # for auto-tagging mp3s
    $ pip install pyacoustid  # for identifying mp3s by acoustic signature
    $ vim ~/.config/beets/config.yaml
    # Identify songs by acoustic signature with hints from the filename
    plugins:
        - chroma
        - fromfilename
    $ bash server.sh

Example:

    $ bash server.sh
    Ncat: Ncat: Version 6.40 ( http://nmap.org/ncat )
    Version 6.40 ( http://nmap.org/ncat )
    Ncat: Ncat: Listening on 0.0.0.0:8675
    ----
    $ bash client.sh
    $ shit> connect 0.0.0.0 8675
    $ shit> shit -u https://www.youtube.com/watch?v=MKp30C3MwVk
    $ Added mp3
    $ shit> play
    ♫ ♪ ♩
    $ shit> help

TODO:
* Instant return of commands from server and server communicates command status async
* Keep mp3s on client for cache or adding to personal music collection
* Separate server log messages by client
* SSL
* Users (song added by userx)
* Passwords and/or stream passwords
