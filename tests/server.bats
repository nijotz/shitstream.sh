#!/usr/bin/env bats

server_pid=0
setup() {
    bash server.sh &
    server_pid=$!
    echo $server_pid > $BATS_TMPDIR/server.pid
    echo $server_pid > /tmp/server.pid
}

teardown() {
    kill $(cat $BATS_TMPDIR/server.pid) && echo good >> /tmp/testing
    wait $server_pid && echo good2 >> /tmp/testing
    echo $? >> /tmp/testing
}

@test "Test pinging server" {
#testing() {
    rm -f /tmp/testing
    touch /tmp/testing
    state="start"
    sleeptime=0
    (
        while [ $state != "finished" ]; do
            if [ $state == "start" ]; then
                echo "SHIT 1"
                state="connected"
            elif [ $state == "connected" ]; then
                echo "ping"
                echo
                state="waiting"
            elif [ $state == "waiting" ]; then
                sleeptime=$(( $sleeptime + 1 ))
                if [ $sleeptime -gt 10 ]; then
                    state=finished
                elif [ "$(wc -c < /tmp/testing)" -gt 3 ]; then
                    state=finished
                else
                    sleep 1
                fi
            fi
        done 
    ) > >(ncat 0.0.0.0 8675 > /tmp/testing)

    [ "$(cat /tmp/testing)" == "pong" ]
}

#testing
