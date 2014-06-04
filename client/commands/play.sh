#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

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

    ( source $DIR/../player.sh ) &
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
