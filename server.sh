#!/bin/bash

function handle_sigint {
    for proc in $(jobs -p)
    do
        echo killing $proc
        kill $proc
    done
}

trap handle_sigint SIGINT
ncat -vlk -c 'bash connhandle.sh' 0.0.0.0 8675 &
wait %1
