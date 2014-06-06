#!/bin/bash

# STDERR can't be used because it confuses tput and fucks up the screen
# http://stackoverflow.com/questions/21763397/curious-tput-behavior-with-stderr-redirection

function startup_logging {
    exec 9>> ${SHIT_DIR}/client.log
}

function cleanup_logging {
    exec 9>&-
}

function log {
    level=$(echo $1 | tr '[:lower:]' '[:upper:]')
    shift
    msg=$*

    if [[ ! $level =~ INFO|ERROR|DEBUG ]]; then
        msg="$level $msg"
        level="ERROR"
    fi

    echo "[${level}] $msg" >&9
}
