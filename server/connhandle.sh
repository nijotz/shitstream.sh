#!/bin/bash

set -e

# File descriptor 3 will be for sending data to the client. 2 and 1 will be
# sent to the terminal
exec 3>&1 1>&2

LOCKFILE="shit.lock"
MP3DIR="mp3s"
mkdir -p ${MP3DIR}/in

# For now just echo, will add verbosity options later
function v {
    echo $*
}

CURRENT="current"
#STANDBY="trumpet.mp3"
trap "rm -f $LOCKFILE; exit" INT TERM EXIT


# Makes assumptions about cwd
function download_youtube_mp3 {
    # I put underscores everywhere so they wouldn't clash with vars in the
    # calling function

    local _url=$1
    local _returnvar=$2

    mkdir -p "youtube"
    pushd youtube > /dev/null

    v "Connecting to URL"
    if ! curl -I $_url >/dev/null 2>&1; then
        v "Couldn't connect"
        return 1
    fi

    v "Connected to URL, converting to mp3"

    # File descriptor 4 will be a duplicate of 1 so that 4 can be used in a
    # tee below.  I want to capture the output of the youtube-dl command,
    # but also log it to the terminal
    exec 4>&1
    local _output=$(youtube-dl --keep --extract-audio --audio-format mp3 \
        --no-post-overwrites $_url | tee >(cat - >&4))

    local _alreadyexists=$(echo "$_output" | grep -c 'exists, skipping')
    if [ $_alreadyexists -gt 0 ]; then
        v "MP3 exists, skipping conversion"
        local _mp3namestart='.*Post-process file \(.*\) exists, skipping'
        local _mp3=$(echo "$_output" | grep "$_mp3namestart" | sed "s/$_mp3namestart/\1/")
    else
        local _mp3namestart='^.ffmpeg. Destination: '
        local _mp3=$(echo "$_output" | grep "$_mp3namestart" | sed "s/$_mp3namestart//")
    fi

    popd > /dev/null
    ln -sf "youtube/$_mp3" .

    if [ -z "$_mp3" ]; then
        v "mp3 name could not be found!"
        return 1
    fi

    # eval bad. $'...' good.
    eval $_returnvar=$'$_mp3'
}

function connection_handler {

    read line;
    apiversion=$line

    re='SHIT [0-9][0-9]*'
    if [[ ! $apiversion =~ $re ]]; then
        v "Protocol error: expected SHIT [0-9]"
        echo "Protocol error: expected SHIT [0-9]" >&3
        exit 1
    fi


    # TODO: load api files

    v "Handling command"
    while true; do
        read line; command=$line

        local i=0
        read line
        while [ ! -z "$line" ]; do
            options[i]=$line
            i=$(($i + 1))
            read line
        done

        if ! output=$(declare -f | grep "command_${command} ()"); then
            v "Invalid command: $command"
            echo Invalid command: $command >&3
            echo >&3
        else
            v "Running command: $command"
            command_$command "${options[@]}"
        fi
    done
}

function command_ping {
    v "PONGing a PING"
    echo pong >&3
    while [[ $# > 0 ]] ; do
        echo $1 >&3
        shift
    done
    echo >&3
}

# Assumes given mp3 is in the "in" directory
function process_mp3 {
    mp3=$1

    v "Applying ReplayGain"
    # readlink -f is to resolve symlinks since mp3gain makes a temp file and
    # overwrites original which unlinks the symlink and doesn't modify the
    # original
    mp3gain -r -s i "$(readlink -f "${MP3DIR}/in/$mp3")"

    v "Tagging mp3"
    beet import -qsC "${MP3DIR}/in/$mp3"

    v "Linking mp3"
    pushd ${MP3DIR} > /dev/null
    ln -s "in/$mp3" $(date +%s.%N).mp3
    popd > /dev/null

    echo -e "Added mp3\n" >&3
}

function command_shit_url {
    url=$1

    v "Testing URL"

    if echo "$url" | grep -E '^https?://(www\.)?youtube' > /dev/null; then

        v "It's a youtube URL"
        mp3=""
        pushd ${MP3DIR}/in/ > /dev/null
        download_youtube_mp3 $url mp3
        popd > /dev/null
        exitstatus=$?

        if [ $exitstatus -ne 0 ]; then
            echo -e "Could not download mp3\n" >&3
            return 1
        fi

        process_mp3 "$mp3"
    else
        echo -e "Youtube URLs only\n" >&3
        return 1
    fi
}

function command_shit_mp3 {
    length=$1
    mp3=$(date +%s.%N).mp3
    pushd ${MP3DIR}/in > /dev/null
    head -c $length > $mp3
    popd > /dev/null
    process_mp3 "$mp3"
    echo "mp3 received" >&3
}

function command_shit_on_me {
    mkdir -p $MP3DIR
    pushd $MP3DIR > /dev/null

    # Protect against race conditions
    v "Obtaining lockfile"
    lockfile -1 -r 60 $LOCKFILE
    if [ $? -ne 0 ]; then
        echo "Could not obtain lock file"
        return 1
    fi

    function stream_song {
        rm $LOCKFILE
        wc -c < "$1" >&3
        cat "$1" >&3
    }

    # See if there's a song currently targeted for streaming
    if [ -f $CURRENT ]; then
        v "Found a currently streaming song"
        current_mp3=$(head -n 1 $CURRENT)
        expires=$(tail -n 1 $CURRENT)
    fi

    # Expire the currently streaming mp3 if necessary
    current_time=$(date +%s)
    v "Song expires at: $expires"
    v "Date is: $current_time"
    if [ ! -z "$expires" ] && [ $expires -lt $current_time ]; then
        v "Expiring current song"
        rm -f "$current_mp3"
        cat "/dev/null" > $CURRENT
    fi

    # Stream the file if it exists
    if [ ! -z "$current_mp3" ] && [ -f "$current_mp3" ]; then
        v "Streaming current song"
        stream_song "$current_mp3"
        return
    fi

    # Find the next mp3 to play
    v "Finding another mp3 to play"
    for file in $(ls | grep '^[0-9\.]*\.mp3$'); do
        v "Testing $file"
        length=$(sox -t mp3 "$file" -n stat 2>&1 | grep Length | sed 's/[^0-9.]//g' | sed 's/\..*//')

        # Not a valid mp3
        if [ -z "$length" ]; then
            v "$file is not a valid mp3, removing"
            rm $file
            continue
        fi

        # Found a file, stream and break from loop
        echo $file > $CURRENT
        echo $(( $length + $current_time ))>> $CURRENT

        v "Streaming $file"
        stream_song "$file"
        return
    done
    v "Couldn't find a queued mp3"

    # Play the standby mp3 if one is defined
    if [ -n "$STANDBY" ]; then
        v "Playing standby"
        stream_song "$STANDBY"
        return
    fi

    # Play a randomly uploaded mp3
    v "Playing random mp3"
    mp3=$(ls in | sort -R | tail -n 1)
    if [ -n "$mp3" ]; then
        v "Streaming in/$mp3"
        stream_song "in/$mp3"
        return
    fi

    v "Couldn't find an mp3"
    return 1
}

v "Handling connection"
connection_handler
