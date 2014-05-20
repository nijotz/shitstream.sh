#!/bin/bash

source mp3base.sh

# Swap stdout and stderr. Stdout will go to the terminal now and stderr will go
# to the client
exec 3>&2 2>&1 1>&3

CURRENT="current"
STANDBY="trumpet.mp3"

if [ ! -d $MP3DIR ]; then
    mkdir $MP3DIR
fi
cd $MP3DIR

# Protect against race conditions
v "Obtaining lockfile"
lockfile -1 -r 60 $LOCKFILE || exit 1
trap "rm -f $LOCKFILE; exit" INT TERM EXIT

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
    cat $current_mp3 >&2
    exit
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
    cat $file >&2
    exit
done

# Play the standby mp3 if there aren't any uploaded ones
v "Playing standby"
cat $STANDBY >&2
