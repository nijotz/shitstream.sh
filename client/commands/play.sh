#!/bin/bash

stream_pid=0
function command_play {
    helptext="Play some shit that's on the server" # shellcheck disable=SC2034
    helptext="Usage: play" # shellcheck disable=SC2034

    if ! is_connected; then
        print_text "You need to connect first"
        return
    fi

    if is_streaming; then
        print_text "Currently streaming, disconnect first"
        return 1
    fi

    play_stream &
    stream_pid=$!
}

function command_stop {
    helptext="Stop playing the shit coming from the server" # shellcheck disable=SC2034
    helptext="Usage: stop" # shellcheck disable=SC2034

    if is_streaming; then
        kill "$stream_pid"
        wait "$stream_pid"
        stream_pid=0
        #TODO: shit needs to go in the toilet
        export status_connection="Connected to $shit_server $shit_port"
    fi
}

function command_pause {
    helptext="Pause/unpause the shit coming from the server" # shellcheck disable=SC2034
    helptext="Usage: pause" # shellcheck disable=SC2034

    if is_streaming; then
        # shellcheck disable=SC2015
        player_pause && print_text Paused || print_text Unpaused
    else
        print_text "Not streaming"
    fi
}

function is_streaming {
    [ "$stream_pid" -eq 0 ] && return 1
    return 0
}
