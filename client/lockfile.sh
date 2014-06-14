#!/bin/bash

# Define a lockfile funtion if lockfile and flock are not installed

function lockdir {
    mkdir "$1" && return 0
    return 1
}

function lockclear {
    rm -f "$1" 2>/dev/null || rmdir "$1" 2>/dev/null
}

function v {
    if [[ $verbose == 1 ]]; then
        echo $*
    fi
}

#nodeps
function lockfile {
    local retries=3
    local sleeptime=1
    local verbose=0
    local OPTION
    local OPTARG
    local OPTIND
    local lock=""

    while getopts ":r:t:v" OPTION
    do
        case $OPTION in
            r)
                retries=$OPTARG
                ;;
            v)
                verbose=1
                ;;
            t)
                if [[ $OPTARG =~ [0-9]+ ]]; then
                    sleeptime=$OPTARG
                else
                    echo "Invalid sleep time: $OPTARG"
                    return 1
                fi
                ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                return 1
                ;;
            :)
                echo "Option -$OPTARG requires an argument." >&2
                return 1
                ;;
        esac
    done

    local tries=0
    argarray=( "$@" )
    lock="${argarray[$(( OPTIND - 1 ))]}"
    while ! lockdir "$lock" 2>/dev/null; do
        v "Lock failed on $lock"

        tries=$(( tries + 1 ))
        if [[ $tries -gt $retries ]]; then
            v "Too many retries, failed"
            return 1
        fi
        v "$(( retries - tries )) attempt(s) left"

        v "Sleeping $sleeptime seconds"
        sleep $sleeptime
    done
}
