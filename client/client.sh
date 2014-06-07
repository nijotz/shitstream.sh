#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

function traceback {
    # Hide the traceback() call.
    local -i start=$(( ${1:-0} + 1 ))
    local -i end=${#BASH_SOURCE[@]}
    local -i i=0
    local -i j=0

    log ERROR "Traceback (last called is first):"
    echo "Traceback (last called is first):"
    for ((i=${start}; i < ${end}; i++)); do
        j=$(( $i - 1 ))
        local function="${FUNCNAME[$i]}"
        local file="${BASH_SOURCE[$i]}"
        local line="${BASH_LINENO[$j]}"
        log ERROR " ${function}() in ${file}:${line}"
        echo " ${function}() in ${file}:${line}"
    done
}

function kill_tree {
    local _pid=$1
    local _sig=${2:-TERM}
    local _children=${3:-0}  # Whether to kill children only

    # needed to stop quickly forking parent from producing children between
    # child killing and parent killing
    if [ $_children -eq 0 ]; then
        log DEBUG "Stopping ${_pid}"
        kill -stop ${_pid} 2>/dev/null || true
    fi

    for _child in $(pgrep -P ${_pid}); do
        log DEBUG "Found child of $_pid ($_child), killing child tree"
        kill_tree ${_child} ${_sig}
    done

    if [ $_children -eq 0 ]; then
        log DEBUG "Killing $_pid"
        kill -${_sig} ${_pid} 2>/dev/null || true
    fi
}

function prompt {
    while true; do
        # TODO: Improve how stream status is passed from the child process. The
        # streaming subprocess puts its status strings in toilet.  Load it for
        # the status bar.
        test -f ${SHIT_DIR}/toilet && source ${SHIT_DIR}/toilet
        print_status_bar
        tput cup $(tput lines) 0

        # Read input with readline support (-e), ctrl-d will quit
        read -e -p "shit> " input 2>&1 || command_quit

        # Ignore empty input
        if [ -z "$input" ]; then continue; fi

        log DEBUG "Handling input: $input"
        handle_input $input
    done
}

function handle_input {
    command=${1}; shift

    # Append command to history
    history -s $command $*

    print_text "shit> $command $*"

    # Look for the command by looking for a function named after it
    log DEBUG "Looking for defined command: ${command}"
    if ! output=$(declare -f | grep "command_${command} ()"); then
        print_text Invalid command: $command
    else
        command_$command $* || return $?
    fi
}

function usage {
cat << EOF
usage: $0 options

Dive into the shit stream (tm)

OPTIONS:
   -h      Help
   -d      Shit directory

$0 -p 5678 -r 0.5 -s 10 -v
EOF
}

function main {
    SHIT_DIR=~/.shitstream

    # Parse args
    while getopts "h:d" OPTION
    do
      case $OPTION in
        h)
          usage
          exit
          ;;
        d)
          SHIT_DIR=$OPTARG
          ;;
      esac
    done

    mkdir -p $SHIT_DIR

    # Source files, now that SHIT_DIR is set
    for f in $(dirname $0)/*; do
        if [ $f != $0 ] && [ -f $f ]; then
            echo "Sourcing $f"
            source $f
        fi
    done
    for f in $(dirname $0)/commands/*; do
        echo "Sourcing $f"
        source $f
    done

    # Load history file for readline
    hist_file=${SHIT_DIR}/history
    [ -f $hist_file ] && history -r $hist_file

    tput smcup  # Save terminal screen
    tput clear  # Clear screen
    tput cup $(tput lines) 0  # Move cursor to last line, first column

    # Call logging startup manually, so logging can happen ASAP
    startup_logging
    log INFO "Calling startup function: startup_logging"

    # Call startup functions from sourced files
    for startup in $(declare -f | grep startup_ | sed 's/ \(\).*//'); do
        if [ $startup == "startup_logging" ]; then continue; fi
        log INFO "Calling startup function: $startup"
        $startup
    done

    log INFO "Startup done, prompting user"

    # Start prompt loop
    prompt
}

function command_quit {
    helptext="duh."

    status=${*:-good}

    log INFO "Quitting ($status)"

    # If exiting because of error then show traceback
    if [ "$status" == "good" ]; then
        tput rmcup  # Restore original terminal output
    else
        echo $status
        traceback 1
    fi

    # Clear trap, so it doesn't get called on exit or errors
    trap - EXIT ERR

    kill_tree $$ TERM 1 || true

    # Write history file
    history -w ${SHIT_DIR}/history

    # Call all cleanup functions from source files
    for cleanup in $(declare -f | grep cleanup_ | sed 's/ .*//'); do
        if [ $cleanup == "cleanup_logging" ]; then continue; fi
        log INFO "Calling cleanup function: $cleanup"
        $cleanup
    done

    # Call logging cleanup manually, so logging can happen ALAP
    log INFO "Calling cleanup function: cleanup_logging"
    cleanup_logging

    exit
}
trap "command_quit Caught signal" SIGINT SIGTERM SIGHUP
trap "command_quit Error/exit" EXIT ERR

main
