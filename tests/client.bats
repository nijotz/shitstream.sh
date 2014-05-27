#!/usr/bin/env bats

setup() {
    bash server.sh &
    echo $! > $BATS_TMPDIR/server.pid
    sleep 1
}

teardown() {
    server_pid=$(cat $BATS_TMPDIR/server.pid)
    kill $server_pid
    wait $server_pid
}

@test "Test connection" {
    function good_connection {
        echo connect 0.0.0.0 8675 | bash client.sh
    }
    run good_connection
    output=$(for item in ${lines[*]}; do echo $item; done)
    output=$(echo $output |
        sed -e '/Connecting to 0.0.0.0:8675/,/Connected to 0.0.0.0:8675/!d')
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "Test handling of bad connection" {
    function bad_connection {
        echo connect 0.0.0.0 8676 | bash client.sh
    }
    run bad_connection
    output=$(for item in ${lines[*]}; do echo $item; done)
    output=$(echo $output |
        sed -e '/Connecting to 0.0.0.0:8676/,/Connection refused/!d')
    [ "$status" -eq 1 ]
    [ -n "$output" ]
}
