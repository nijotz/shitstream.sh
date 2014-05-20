shitstream
==========

Example:

    $ bash server.sh
    Ncat: Ncat: Version 6.40 ( http://nmap.org/ncat )
    Version 6.40 ( http://nmap.org/ncat )
    Ncat: Ncat: Listening on 0.0.0.0:8675
    Listening on 0.0.0.0:6753
    ----
    $ cat ~/media/mp3/Merzbow/dev-urandom.mp3 | ncat 0.0.0.0 8675
    $ bash client.sh 0.0.0.0 6753
    ♫ ♪ ♩

TODO:
* Keep old mp3s around for streaming when nothing is queued
* Client should use nc/netcat/ncat, whatever is available
