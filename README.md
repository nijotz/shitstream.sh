[![Build Status](https://travis-ci.org/nijotz/shitstream.svg?branch=master)](https://travis-ci.org/nijotz/shitstream)
shitstream
==========

Prerequisites (client):
* ncat (part of the nmap package usually)
* mpg123 (or afplay [OSX], mplayer, ffplay, cvlc)

Prerequisites (server):
* sox
* curl

Example:

    $ bash server.sh
    Ncat: Ncat: Version 6.40 ( http://nmap.org/ncat )
    Version 6.40 ( http://nmap.org/ncat )
    Ncat: Ncat: Listening on 0.0.0.0:8675
    ----
    $ bash client.sh
    $ shit> connect 0.0.0.0 8675
    ♫ ♪ ♩
    $ shit> help

TODO:
* Keep old mp3s around for streaming when nothing is queued
* Keep mp3s on client for cache or adding to personal music collection
* Client should use nc/netcat/ncat, whatever is available
* Separate server log messages by client
* SSL
* Users (song added by userx)
* Passwords and/or stream passwords
* Named mp3s
