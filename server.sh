#!/bin/bash

function handle_sigint {
    for proc in $(jobs -p)
    do
        echo killing $proc
        kill $proc
        wait $proc
    done

    exit 0
}

trap handle_sigint SIGINT SIGTERM EXIT
ncat -vlk -c 'bash connhandle.sh' 0.0.0.0 ${1:-8675} &
wait %1
