#!/bin/bash

function startup_logging {
    exec 2>> ${SHIT_DIR}/client.log
    log INFO "Setup logging"
}

function log {
    level=$(echo $1 | tr '[:lower:]' '[:upper:]')
    shift
    msg=$*

    if [[ ! $level =~ INFO|ERROR|DEBUG ]]; then
        msg="$level $msg"
        level="ERROR"
    fi

    echo "[${level}] $msg" >&2
}
