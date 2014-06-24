#!/usr/bin/env bats

base_dir=$(pwd) # Assume we're in the root path of the source
client_dir=$base_dir/client/
server_dir=$base_dir/server/

run=bash
if [ -n "$SHCOV" ]; then
    run=shcov
fi

function mpg123 {
    $(which mpg123) -t $*
}
export -f mpg123

setup() {
    $run $server_dir/server.sh 8676 &
    echo $! > $BATS_TMPDIR/server.pid
    sleep 1
}

teardown() {
    server_pid=$(cat $BATS_TMPDIR/server.pid)
    kill $server_pid
    wait $server_pid
}

function test_status_output {
    run $1
    echo "Status: $status"
    # Breaks on linux, tests just hang here
    echo "Output: ${lines[@]}" #| col -b # Get rid of esc sequences
    [ "$status" -eq $2 ]
    [ $(echo ${lines[@]} | grep -c "$3") -ne "0" ]
}

function run_client {
    $run $client_dir/client.sh -d "$BATS_TMPDIR/shistream/"
}

@test "Test connection" {
    function good_connection {
        echo connect 0.0.0.0 8676 | run_client
    }
    test_status_output \
        good_connection \
        0 \
        'Connecting to 0.0.0.0:8676.*Connected to 0.0.0.0:8676'
}

@test "Test handling of bad connection" {
    function bad_connection {
        echo connect 0.0.0.0 8677 | run_client
    }
    test_status_output \
        bad_connection \
        0 \
        'Connecting to 0.0.0.0:8677.*Connection refused'
}

# Run all arguments as commands with a sleep in between
function client_commands {

    fifo=${BATS_TMPDIR}/client.fifo
    mkfifo $fifo
    line=""

    while [ "$line" != "quit" ]; do
        read line < $fifo
        echo $line
    done | run_client &

    for cmd in "$@"; do
        echo "$cmd" > $fifo
        sleep 1
    done
    echo "quit" > $fifo

    rm -f $fifo
}

function ping {
    client_commands 'connect 0.0.0.0 8676' 'ping'
}

@test "Test client ping" {
    test_status_output ping 0 'Connecting to 0.0.0.0:8676.*pong'
}

@test "Test client cleanup" {
    run ping
    [ "$(ls ~/.shitstream | grep -Ev '(^history$|^config$|^mp3$|^client.log$)' | wc -l)" == "0" ]
}

@test "Test playing" {
    function play {
        client_commands 'connect 0.0.0.0 8676' 'play' 'help'
    }
    test_status_output play 0 '.'
}

@test "Test typing play twice" {
    function playplay {
        client_commands 'connect 0.0.0.0 8676' 'play' 'play'
    }
    test_status_output playplay 0 '.'
}
