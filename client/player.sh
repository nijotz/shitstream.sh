#!/bin/bash

function startup_player {
    rm -f ${SHIT_DIR}/mpg123.fifo
    mkfifo ${SHIT_DIR}/mpg123.fifo
    (
        # jesus fuck, bash makes me do stupid shit
        {
            mpg123 --fifo ${SHIT_DIR}/mpg123.fifo -R 2>/dev/null &
            echo $! > ${SHIT_DIR}/mpg123.pid
        } | while read line; do
            echo $line > ${SHIT_DIR}/mpg123.out
        done
    ) &
    mpg123_pid=$(cat ${SHIT_DIR}/mpg123.pid)
    log DEBUG "mpg123 pid: $mpg123_pid"
    sleep 1
    echo silence > ${SHIT_DIR}/mpg123.fifo
}

function cleanup_player {
    log INFO "Cleaning up player"

    pidf=${SHIT_DIR}/mpg123.pid
    [ -f $pidf ] && pid=$(cat $pidf) && kill $pid

    rm -f ${SHIT_DIR}/mpg123.pid
    rm -f ${SHIT_DIR}/toilet  # Used to communicate player status to status bar
    rm -f ${SHIT_DIR}/mpg123.fifo
    rm -f ${SHIT_DIR}/mpg123.out

}
trap cleanup_player SIGINT SIGTERM SIGHUP EXIT

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

function player_command {
    echo "$*" > ${SHIT_DIR}/mpg123.fifo
    cat ${SHIT_DIR}/mpg123.out
}

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

        # Update status bar
        update_status_bar "Playing from $shit_server $shit_port" "$(identify_mp3 ${SHIT_DIR}/mp3)"

        # Load song
        output=$(player_command "L ${SHIT_DIR}/mp3")

        # Wait for end of song
        stat=""
        while [ "$stat" != "@E No stream opened. (code 24)" ]; do
            stat=$(player_command sample)
            sleep 1
        done
        print_text "mp3 finished, requesting new one"
    done
}
