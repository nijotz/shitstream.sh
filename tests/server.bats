#!/usr/bin/env bats

server_pid=0
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

@test "Test pinging server" {
    exec 5<>/dev/tcp/0.0.0.0/8675
    echo -e "SHIT 1\nping\n\n" >&5
    read line <&5
    exec 5<&-
    [ "$line" == "pong" ]
}
