#!/usr/bin/env bats

base_dir=$(pwd) # Assume we're in the root path of the source
client_dir=$base_dir/client/
server_dir=$base_dir/server/

setup() {
    bash $server_dir/server.sh 8676 &
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
    [ "$2" -eq 0 ]
    [ $(echo ${lines[@]} | grep -c "$3") -ne "0" ]
}

@test "Test connection" {
    function good_connection {
        echo connect 0.0.0.0 8676 | bash $client_dir/client.sh
    }
    test_status_output \
        good_connection \
        0 \
        'Connecting to 0.0.0.0:8676.*Connected to 0.0.0.0:8676'
}

@test "Test handling of bad connection" {
    function bad_connection {
        echo connect 0.0.0.0 8677 | bash $client_dir/client.sh
    }
    test_status_output \
        bad_connection \
        0 \
        'Connecting to 0.0.0.0:8677.*Connection refused'
}

function ping {
    fifo=${BATS_TMPDIR}/client.fifo
    mkfifo $fifo
    line=""
    while [ "$line" != "quit" ]; do
        read line < $fifo
        echo $line
    done | bash $client_dir/client.sh &
    echo 'connect 0.0.0.0 8676' > $fifo
    sleep 2
    echo 'ping' > $fifo
    sleep 2
    echo 'quit' > $fifo
    rm -f $fifo
}

@test "Test client ping" {
    test_status_output ping 0 'Connecting to 0.0.0.0:8676.*pong'
}

@test "Test client cleanup" {
    run ping
    [ "$(ls ~/.shitstream | grep -Ev '(^history$|^config$|^mp3$|^client.log$)' | wc -l)" == "0" ]
}
