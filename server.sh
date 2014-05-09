#!/bin/bash

function handle_sigint()
{
    for proc in $(jobs -p)
    do
        echo killing $proc
        kill $proc
    done
}

trap handle_sigint SIGINT

ncat -vlk -c 'bash mp3receiver.sh' 0.0.0.0 8675 &
ncat -vlk -c 'bash mp3sender.sh' 0.0.0.0 6753 &

wait %1
wait %2
