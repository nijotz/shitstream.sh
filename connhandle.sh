#!/bin/bash

set -e

# File descriptor 3 will be for sending data to the client. 2 and 1 will be
# sent to the terminal
exec 3>&1 1>&2

source mp3base.sh
CURRENT="current"
STANDBY="trumpet.mp3"
trap "rm -f $LOCKFILE; exit" INT TERM EXIT

function download_youtube_mp3 {

    local url=$1
    local returnvar=$2

    v "Connecting to URL"
    if ! curl -I $url >/dev/null 2>&1; then
        v "Couldn't connect"
        return 1
    fi

    v "Connected to URL, converting to mp3"

    # File descriptor 4 will be a duplicate of 1 so that 4 can be used in a
    # tee below.  I want to capture the output of the youtube-dl command,
    # but also log it to the terminal
    exec 4>&1
    local output=$(youtube-dl --keep --extract-audio --audio-format mp3 \
        --no-post-overwrites $url | tee >(cat - >&4))

    local alreadyexists=$(echo "$output" | grep -c 'exists, skipping')
    if [ $alreadyexists -gt 0 ]; then
        v "MP3 exists, skipping conversion"
        local mp3namestart='.*Post-process file \(.*\) exists, skipping'
        local mp3=$(echo "$output" | grep "$mp3namestart" | sed "s/$mp3namestart/\1/")
    else
        local mp3namestart='^.ffmpeg. Destination: '
        local mp3=$(echo "$output" | grep "$mp3namestart" | sed "s/$mp3namestart//")
    fi

    eval $returnvar="'$mp3'"

    if [ -z "$mp3" ]; then
        v "mp3 name could not be found!"
        return 1
    fi
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

        pushd ${MP3DIR} > /dev/null
        v "Linking mp3"
        ln -s "in/$mp3" $(date +%s.%N).mp3
        popd > /dev/null
    else
        echo -e "Youtube URLs only\n" >&3
        return 1
    fi

    echo -e "Added mp3\n" >&3
}

function command_shit_mp3 {
    length=$1
    mp3=$(date +%s.%N).mp3
    cd ${MP3DIR}/in
    head -c $length > $mp3
    cd ..
    ln -s "in/$mp3" $(date +%s.%N).mp3
    cd ..

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
        wc -c < $1 >&3
        cat $1 >&3
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
        rm $current_mp3
        cat "/dev/null" > $CURRENT
    fi

    # Stream the file if it exists
    if [ ! -z "$current_mp3" ] && [ -f "$current_mp3" ]; then
        v "Streaming current song"
        stream_song $current_mp3
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
        stream_song $file
        return
    done

    # Play the standby mp3 if there aren't any uploaded ones
    v "Playing standby"
    stream_song $STANDBY
}

v "Handling connection"
connection_handler
