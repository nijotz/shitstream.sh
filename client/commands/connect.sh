#!/bin/bash

shit_server=""
shit_port=""

connection_pid=0
function command_connect {
    helptext="Connect to a stream of shit" # shellcheck disable=SC2034
    helptext="Usage: connect <server> <port>" # shellcheck disable=SC2034

    if [ -n "$shit_server" ]; then
        command_disconnect
    fi

    print_text "Connecting to $1:$2"
    { exec 3<> "/dev/tcp/$1/$2"; } 2>/dev/null
    if [ $? -ne 0 ]; then
        print_text 'Connection refused'
        return
    fi

    shit_server=$1
    shit_port=$2

    echo -e 'SHIT 1' >&3

    (
        trap command_disconnect EXIT
        while true; do
            read line <&3
            if [ -n "$line" ]; then
                print_server_text "$line"
            fi
        done
    ) &
    connection_pid=$!
    log DEBUG "Connection pid: $connection_pid"

    export status_connection="Connected to $shit_server $shit_port"
    print_text "Connected to $1:$2"
}

function command_disconnect {
    helptext="Disconnect from current stream of shit" # shellcheck disable=SC2034
    helptext="Usage: disconnect" # shellcheck disable=SC2034

    if ! is_connected; then
        print_text "Not connected"
        return
    fi

    print_text "Disconnecting from ${shit_server}:${shit_port}"

    if is_streaming; then
        command_stop
    fi

    kill "$connection_pid"
    wait "$connection_pid"
    shit_server=""
    shit_port=""
    connection_pid=0

    exec 3<&-

    status_connection="Not connected"
}

function is_connected {
    if [ "$connection_pid" -eq 0 ]; then
        return 1
    fi
    return 0
}
