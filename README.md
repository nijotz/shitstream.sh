shitstream
==========

Example:

    $ bash server.sh
    Ncat: Ncat: Version 6.40 ( http://nmap.org/ncat )
    Version 6.40 ( http://nmap.org/ncat )
    Ncat: Ncat: Listening on 0.0.0.0:8675
    ----
    $ bash client.sh
    $ shit> connect 0.0.0.0 8675
    ♫ ♪ ♩

TODO:
* Keep old mp3s around for streaming when nothing is queued
* Keep mp3s on client for cache or adding to personal music collection
* Client should use nc/netcat/ncat, whatever is available
