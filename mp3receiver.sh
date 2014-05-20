#!/bin/bash

set -e

# Send stdout to stderr. Sending to stdout would go to the client.
exec 1>&2

source mp3base.sh

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
        local mp3=$(echo output | sed 's/.*Post-process file \(.*\) exists, skipping/\1/')
    else
        local mp3namestart='^.ffmpeg. Destination: '
        local mp3=$(echo "$output" | grep "$mp3namestart" | sed "s/$mp3namestart//")
    fi

    eval $returnvar="'$mp3'"

    if [ -z "$mp3" ]; then
        v "mp3 name could not be found!"
        exit 1
    fi
}

v "Receiving mp3"

mp3=$(date +%s.%N).mp3
pushd ${MP3DIR}/in > /dev/null
cat > $mp3

v "Testing to see if a URL has been uploaded"
grep -E '^https?://(www\.)?youtube' $mp3 > /dev/null
exitstatus=$?

if [ $exitstatus -eq 0 ]; then

    v "It's a youtube URL"
    url=$(cat $mp3)
    newmp3=""
    download_youtube_mp3 $url newmp3
    exitstatus=$?

    v "Removing URL file"
    rm $mp3
    mp3=$newmp3

    if [ $exitstatus -ne 0 ]; then
        v "Could not download mp3"
        exit
    fi
else
    v "MP3 file uploaded"
fi

v "Done with mp3 upload/conversion"

popd > /dev/null
pushd ${MP3DIR} > /dev/null
v "Linking mp3"
ln -s "in/$mp3" $(date +%s.%N).mp3 2>&1
popd > /dev/null
