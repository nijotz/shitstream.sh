#!/bin/bash

shit_server=""
shit_port=""

function command_connect {
    helptext="Connect to a stream of shit"
    helptext="Usage: connect <server> <port>"

    if [ -n "$shit_server" ]; then
        command_disconnect
    fi

    print_text "Connecting to $1:$2"
    { exec 3<> /dev/tcp/$1/$2; } 2>/dev/null
    if [ $? -ne 0 ]; then
        print_text 'Connection refused'
        return 1
    fi

    shit_server=$1
    shit_port=$2

    echo -e 'SHIT 1' >&3

    (
        while true; do
            read line <&3
            if [ -n "$line" ]; then
                print_server_text "$line"
            fi
        done
    ) &
    connection_pid=$!

    status_connection="Connected to $shit_server $shit_port"
    print_text "Connected to $1:$2"
}

function command_disconnect {
    helptext="Disconnect from current stream of shit"
    helptext="Usage: disconnect"

    if ! is_connected; then
        print_text "Not connected"
        return 1
    fi

    print_text "Disconnecting from ${shit_server}:${shit_port}"

    if is_streaming; then
        command_stop
    fi

    kill $connection_pid
    wait $connection_pid
    shit_server=""
    shit_port=""
    connection_pid=0

    exec 3<&-

    status_connection="Not connected"
}

function is_connected {
    [ "$connection_pid" -eq 0 ] && return 1
    return 0
}
