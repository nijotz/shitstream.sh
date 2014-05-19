#!/bin/bash

set -e

# swap stdout and stderr since anything sent to stdout would go to the client
exec 1>&2

source mp3base.sh

echo "Receiving mp3"

mp3=$(date +%s.%N).mp3
test ! -d ${MP3DIR}/in && mkdir -p ${MP3DIR}/in
pushd ${MP3DIR}/in > /dev/null
cat > $mp3

echo "Testing to see if a URL has been uploaded"
grep -E '^https?://(www\.)?youtube' $mp3 > /dev/null
exitstatus=$?
if [ $exitstatus -eq 0 ]; then

    echo "It's a youtube URL"
    url=$(cat $mp3)

    echo "Connecting to URL"
    if curl -I $url >/dev/null 2>&1; then

        echo "Connected to URL, converting to mp3"

        # File descriptor 4 will be a duplicate of 1 so that 4 can be used in a
        # tee below.  I want to capture the output of the youtube-dl command,
        # but also log it to the terminal
        exec 4>&1
        output=$(youtube-dl --keep --extract-audio --audio-format mp3 \
            --no-post-overwrites $url | tee >(cat - >&4))

        alreadyexists=$(echo "$output" | grep -c 'exists, skipping')
        if [ $alreadyexists -gt 0 ]; then
            echo "MP3 exists, skipping"
            exit
        fi

        mp3namestart='^.ffmpeg. Destination: '
        mp3name=$(echo "$output" | grep "$mp3namestart" | sed "s/$mp3namestart//")
        if [ -z "$mp3name" ]; then
            echo "mp3 name could not be found!"
            exit
        fi
        mp3=$mp3name

        echo "Converted to mp3"
    else
        echo "Couldn't connect"
        rm $mp3
        exit
    fi
else
    echo "MP3 file uploaded"
fi

popd > /dev/null
pushd ${MP3DIR} > /dev/null
echo "Linking mp3"
ln -s "in/$mp3" . 2>&1
popd > /dev/null

echo "Done with mp3 upload/conversion"
