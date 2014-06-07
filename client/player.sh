#!/bin/bash

mpg123_out=${SHIT_DIR}/mpg123.out

function startup_player {

    # jesus fuck, bash makes me do stupid shit
    rm -f $mpg123_out
    touch $mpg123_out

    log INFO "Starting mpg123"
    if ! which mpg123 > /dev/null; then
        command_quit 'mpg123 is required'
    fi
    exec 7> >(
        mpg123 -R 2>/dev/null | while read line; do
            echo $line >> $mpg123_out
        done
    )
    log DEBUG "Started mpg123"

    # Read output of mpg123 for 'ready' signal and send the 'silence' signal
    if player_communication "" '^@R' >/dev/null; then
        if player_communication silence @silence >/dev/null; then
            log INFO "mpg123 initialized"
            return 0
        else
            command_quit "Could not silence mpg123"
        fi
    else
        command_quit "mpg123 failed to load"
    fi
}

function cleanup_player {
    log INFO "Cleaning up player"

    log DEBUG "Closing mpg123 file descriptor"
    exec 7<&-
    log DEBUG "mpg123 file descriptor closed"

    rm -f ${SHIT_DIR}/toilet  # Used to communicate player status to status bar
    rm -f ${SHIT_DIR}/mpg123.in
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

function player_communication {
    if [ -n "${1:-""}" ]; then
        log DEBUG "Sending to mpg123: $1"
        echo "$1" >&7
    fi

    tries=0
    output=""
    sleep_times=( 0.3 0.6 1 3 )
    while : ; do
        if grep -q "${2:-""}" $mpg123_out; then
            output=$(cat $mpg123_out)
            break
        fi
        [ $tries -lt 3 ] || break
        log DEBUG "No mpg123 output, trying again"
        tries=$(( $tries + 1 ))
        sleep ${sleep_times[tries]}
    done

    cat /dev/null > $mpg123_out

    log DEBUG "Got output from mpg123 :: $output ::"

    if [ -n "$output" ]; then
        echo $output
        return 0
    else
        return 1
    fi
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
        output=$(player_communication "L ${SHIT_DIR}/mp3")

        # Wait for end of song
        stat="0"
        while [ "$stat" != "@E No stream opened. (code 24)" ] && [ "$stat" != "" ]; do
            stat=$(player_communication sample @S)
            sleep 10
        done
        print_text "mp3 finished"
    done
}

player_paused=0
function player_pause {
    output=$(player_communication P @P)
    log DEBUG "Pause output: $output"
    player_pause=$( [ "$output" == "@P 1" ] ; echo $? )
    return $player_pause
}
