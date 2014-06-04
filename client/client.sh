#!/bin/bash

SHIT_DIR=~/.shitstream
SHIT_PLAYER=""

stream_pid=0
connection_pid=0

# Initialize status messages
status_connection="Not connected"
status_current_mp3="Not streaming"

source $(dirname $0)/display.sh
for f in $(dirname $0)/commands/*; do
    source $f
done


function prompt {
    while true; do
        # TODO: Improve how stream status is passed from the child process The
        # streaming subprocess puts its status strings in toilet.  Load it for
        # the status bar.
        test -f ${SHIT_DIR}/toilet && source ${SHIT_DIR}/toilet
        print_status_bar
        tput cup $(tput lines) 0

        # Read input with readline support (-e), ctrl-d will quit
        read -e -p "shit> " input
        test $? != 0 && command_quit

        handle_input $input
    done
}

function handle_input {
    command=${1}; shift

    # Ignore empty input
    test "$command" == "" && return

    # Append command to history
    history -s $command $*

    print_text "shit> $command $*"

    # Look for the command by looking for a function named after it
    if ! output=$(declare -f | grep "command_${command} ()"); then
        print_text Invalid command: $command
    else
        command_$command $*
        return $?
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

    mkdir -p ${SHIT_DIR}
    rm -f ${SHIT_DIR}/output.lock
    command_loadcfg ${SHIT_DIR}/config
    history -r ${SHIT_DIR}/history  # Load history file for readline
    tput smcup  # Save terminal screen
    tput clear  # Clear screen
    tput cup $(tput lines) 0  # Move cursor to last line, first column
    prompt
}

function command_quit {
    helptext="duh."

    if is_connected; then
        command_disconnect
    fi

    pkill -P $$

    command_savecfg
    tput rmcup  # Restore original terminal output
    history -w ${SHIT_DIR}/history  # Write history file
    rm -f ${SHIT_DIR}/output.lock
    exit
}
trap command_quit SIGINT SIGTERM SIGHUP EXIT

main
