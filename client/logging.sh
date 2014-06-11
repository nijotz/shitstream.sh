#!/bin/bash

# STDERR can't be used because it confuses tput and fucks up the screen
# http://stackoverflow.com/questions/21763397/curious-tput-behavior-with-stderr-redirection

SHIT_LOGGING_FORMAT=$'[$(date "+%Y-%m-%d %H:%M:%S")] [$level] $msg'
SHIT_LOGGING_LEVEL=DEBUG

_SHIT_LOGGING_ERROR=3
_SHIT_LOGGING_WARN=2
_SHIT_LOGGING_INFO=1
_SHIT_LOGGING_DEBUG=0

function startup_logging {
    exec 9>> ${SHIT_DIR}/client.log
}

function cleanup_logging {
    exec 9>&-
}

function logging_number {
    eval echo \$_SHIT_LOGGING_$1
}

function log {
    level=$(echo $1 | tr '[:lower:]' '[:upper:]')
    shift
    msg=$*

    level_num=$(logging_number $level)
    min_num=$(logging_number $SHIT_LOGGING_LEVEL)
    if [[ -z $level_num ]]; then
        msg="$level $msg"
        level="ERROR"
        level_num=$(logging_number $level)
    fi

    if [[ $level_num -ge min_num ]]; then
        eval echo $SHIT_LOGGING_FORMAT >&9
    fi
}
