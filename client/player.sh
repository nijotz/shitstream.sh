#!/bin/bash

function update_status_bar {
    status_connection=$1
    status_current_mp3=$2
    echo "status_connection=\"$1\"" > ${SHIT_DIR}/toilet
    echo "status_current_mp3=\"$2\"" >> ${SHIT_DIR}/toilet
    print_status_bar
}

function identify_mp3 {
    id3info=$(mpg123-id3dump "$1" 2>&1)
    artist=$(echo -e "$id3info" | sed -nr 's/Artist: (.*)/\1/p')
    track=$(echo -e "$id3info" | sed -nr 's/Title: (.*)/\1/p')

    if [ -z "$artist" ] && [ -z "$track" ]; then
        echo "Unidentified song"
    else
        echo $artist - $track
    fi
}

function cleanup_player {
    print_text "Cleaning up player"

    rm -f ${SHIT_DIR}/toilet

    for job in $(jobs -p); do
        kill $job
        wait $job
    done
}
trap cleanup_player SIGINT SIGTERM SIGHUP EXIT

function play_stream {
    trap cleanup_player SIGINT SIGTERM SIGHUP EXIT

    err=0
    while [ $err -eq 0 ]; do

        # Open connection to server
        exec 4<> /dev/tcp/$shit_server/$shit_port

        # Set protocol and ask for mp3
        echo -e "SHIT 1\nshit_on_me\n" >&4
        print_client_text "shit_on_me"

        # Get length of mp3
        read length <&4
        print_server_text "$length"
        print_server_text "<mp3 data>"
        print_text "Receiving mp3 from server"

        # Read mp3 data
        dd bs=1 count=$length <&4 > ${SHIT_DIR}/mp3 2>/dev/null
        print_text "mp3 received, playing"
        exec 4<&-

        # Upate status bar
        update_status_bar "Playing from $shit_server $shit_port" "$(identify_mp3 ${SHIT_DIR}/mp3)"

        # Start playing mp3
        mpg123 ${SHIT_DIR}/mp3 >/dev/null 2>&1 &
        wait $!
        err=$?

    done
}
