[![Build Status](https://travis-ci.org/nijotz/shitstream-bash.svg?branch=master)](https://travis-ci.org/nijotz/shitstream-bash)

This was fun, but in the end infuriatingly stupid.  "Let's see how far I can push bash".  No.  Bad.  I learned a lot, things I'll probably never have a use for.  A less hipster, more mainstream version of shitstream can be found [here](https://gtihub.com/nijotz/shitstream).  I leave this here as an example to others that may consider writing more than 100 lines of bash for a project.

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
    match:
      strong_rec_thresh: 0.20
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
