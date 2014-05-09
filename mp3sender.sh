#!/bin/bash

LOCKFILE="shit.lock"
CURRENT="current"
MP3DIR="mp3s"
STANDBY="trumpet.mp3"

if [ ! -d $MP3DIR ]; then
    mkdir $MP3DIR
fi
cd $MP3DIR

# Protect against race conditions
lockfile -1 -r 60 $LOCKFILE || exit 1
trap "rm -f $LOCKFILE; exit" INT TERM EXIT

# See if there's a song currently targeted for streaming
if [ -f $CURRENT ]; then
    current_mp3=$(head -n 1 $CURRENT)
    expires=$(tail -n 1 $CURRENT)
fi

# Expire the currently streaming mp3 if necessary
if [ ! -z "$expires" ] && [ $expires -lt $(date +%s) ]; then
    rm $current_mp3
    cat "/dev/null" > $CURRENT
fi

# Stream the file if it exists
if [ ! -z "$current" ] && [ -f "$current" ]; then
    cat $current
    exit
fi

# Find the next mp3 to play
for file in $(ls | grep '^[0-9\.]*$'); do
    length=$(sox -t mp3 $file -n stat 2>&1 | grep Length | sed 's/[^0-9.]//g' | sed 's/\..*//')

    # Not a valid mp3
    if [ -z "$length" ]; then
        rm $file
        continue
    fi

    # Found a file, stream and break from loop
    echo $file > $CURRENT
    echo $(( $length + $(date +%s) ))>> $CURRENT
    
    cat $file
    exit
done

# Play the standby mp3 if there aren't any uploaded ones
cat $STANDBY
