#!/bin/bash

function command_play {
    helptext="Play some shit that's on the server"
    helptext="Usage: play"

    if ! is_connected; then
        print_text "You need to connect first"
        return
    fi

    if is_streaming; then
        print_text "Currently streaming, disconnect first"
        return 1
    fi

    (
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

        function cleanup {
            rm -f ${SHIT_DIR}/toilet
            for job in $(jobs -p); do
                kill $job
                wait $job
            done
        }
        trap cleanup SIGINT SIGTERM SIGHUP EXIT

        err=0
        while [ $err -eq 0 ]; do
            exec 4<> /dev/tcp/$shit_server/$shit_port
            echo -e "SHIT 1\nshit_on_me\n" >&4
            read length <&4
            dd bs=1 count=$length <&4 > ${SHIT_DIR}/mp3 2>/dev/null
            exec 4<&-
            update_status_bar "Playing from $shit_server $shit_port" "$(identify_mp3 ${SHIT_DIR}/mp3)"
            mpg123 ${SHIT_DIR}/mp3 >/dev/null 2>&1 &
            wait $!
            err=$?
        done
    ) &
    stream_pid=$!
}

function command_stop {
    helptext="Stop playing the shit coming from the server"
    helptext="Usage: stop"

    if is_streaming; then
        kill $stream_pid
        wait $stream_pid
        stream_pid=0
        status_connection="Connected to $shit_server $shit_port"
    fi
}

function is_streaming {
    [ "$stream_pid" -eq 0 ] && return 1
    return 0
}
