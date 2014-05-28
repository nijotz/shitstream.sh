#!/usr/bin/env bats

setup() {
    bash server.sh 8676 &
    echo $! > $BATS_TMPDIR/server.pid
    sleep 1
}

teardown() {
    server_pid=$(cat $BATS_TMPDIR/server.pid)
    kill $server_pid
    wait $server_pid
}

@test "Test pinging server" {
    exec 6<>/dev/tcp/0.0.0.0/8676
    echo -e "SHIT 1\nping\n\n" >&6
    read line <&6
    exec 6<&-
    [ "$line" == "pong" ]
}
