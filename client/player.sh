#!/bin/bash

function startup_player {
    local pidf=${SHIT_DIR}/mpg123.pid
    local fifo=${SHIT_DIR}/mpg123.fifo

    # jesus fuck, bash makes me do stupid shit
    touch ${SHIT_DIR}/mpg123.out
    exec 6> >(
        mpg123 -R 2>/dev/null | while read line; do
            echo $line >> ${SHIT_DIR}/mpg123.out
        done
    )

    output=$(player_command silence)
}

function cleanup_player {
    log INFO "Cleaning up player"

    log DEBUG "Closing mpg123 file descriptor"
    exec 6<&-
    log DEBUG "mpg123 file descriptor closed"

    kill_children

    rm -f ${SHIT_DIR}/mpg123.pid
    rm -f ${SHIT_DIR}/toilet  # Used to communicate player status to status bar
    rm -f ${SHIT_DIR}/mpg123.fifo
    rm -f ${SHIT_DIR}/mpg123.out
}

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
    log DEBUG "Sending to mpg123: $*"
    echo "$*" >&6

    outfile=${SHIT_DIR}/mpg123.out
    output=""
    if [ -f $outfile ]; then
        timeout=3
        output=$(cat $outfile)
        while [ -z "$output" ] && [ $timeout != 0 ]; do
            log DEBUG "No output from mpg123, trying again"
            output=$(cat $outfile)
            timeout=$(( $timeout - 1 ))
            sleep 1
        done
    else
        log ERROR "No mpg123 out file"
    fi

    cat /dev/null > $outfile

    log DEBUG "Got output from mpg123 :: $output ::"
    echo $output
}

playing=0
function play_stream {
    # Intended to be backgrounded. If not background these traps will clear the
    # main process's traps
    trap "cleanup_player; playing=0; exit" SIGINT SIGTERM SIGHUP

    playing=1
    while [ $playing -eq 1 ]; do

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
        stat="0"
        while [ "$stat" != "@E No stream opened. (code 24)" ] && [ "$stat" != "" ]; do
            stat=$(player_command sample)
            sleep 10
        done
        print_text "mp3 finished"
    done
}
