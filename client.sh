#!/bin/bash

# Audio programs to use for playing mp3s
audio_programs_Darwin=(afplay)
audio_programs_Linux=(mpg123 mplayer ffplay cvlc)

API_VERSION=1

# Store pid of streaming process
shit_pid=0

# Initialize status messages
status_connection="Not connected"
status_current_mp3="Not connected"

# Used for setting text color/attributes
bld=$(tput bold)
nrm=$(tput sgr0)
grn=$(tput setaf 2)
blu=$(tput setaf 4)

function get_audio_program {
    local result=$1
    os=$(uname)
    #v OS is $os
    programs_var=audio_programs_$os
    programs=${!programs_var}
    for _program in ${programs[@]}; do
        whichprogram=$(which $_program)
        extstatus=$?
        if [ ! $exitstatus ]; then
            #v Using program \'$whichprogram\'
            eval $result="'$whichprogram'"
            return
        fi
    done
}

function prompt {
    while true; do
        show_status_bar
        read -e -p 'shit> ' input
        handle_input $input
    done
}

function handle_input {
    command=$1
    shift

    if [ "$command" == "" ]; then
        return
    fi

    if ! output=$(set | grep "command_${command} ()"); then
        echo Invalid command: $command
    else
        command_$command $*
    fi

    history -s $command $*
}

function show_status_bar {
    tput sc  # Save cursor position
    tput cup 0 0  # Move to top left

    echo "${grn}[${blu}Server:${nrm} ${status_connection}${grn}][${blu}Song:${nrm} $status_current_mp3${grn}]${nrm}"

    tput rc  # Restore cursor position
}

function command_quit {
    helptext="duh."

    for proc in $(jobs -p)
    do
        kill $proc
        wait $proc
    done

    history -w ~/.shit_history
    tput rmcup  # Restore original terminal output
    exit
}

trap command_quit SIGINT SIGTERM SIGHUP EXIT

function command_connect {
    helptext="Connect to a stream of shit"
    helptext="Usage: connect <server> <port>"

    (
        trap exit SIGINT SIGTERM SIGHUP
        while true; do
            ncat --recv-only $1 $2 > /tmp/mp3
            if [ $? ]; then
                echo Connection refused, retrying in 5 seconds...
                sleep 5
            fi
            get_audio_program program
            $program /tmp/mp3
        done
    ) &

    shit_pid=$!
}

function command_disconnect {
    helptext="Disconnect from current stream of shit"
    helptext="Usage: disconnect"

    if [ $shit_pid -ne 0 ]; then
        kill $shit_pid
        shit_pid=0
    else
        echo Not currently streaming
    fi
}

function command_help {
    helptext="Display help for commands"
    helptext="Usage: help <command> [command2] [command3] ..."

    local command

    if [ -z "$@" ]; then
        for command in $(set | grep ^command_ | sed 's/(). *//' | sort); do
            echo $command | sed -r 's/^command_([A-Za-z_]*).*/\1/'
        done
    else
        for command in "$@"; do
            echo "${bld}${command}${nrm}"
            declare -f command_$command | grep '[h]elptext=' | sed 's/^ *[h]elptext=["'"'"']//g' | sed 's/['"'"'"];//'
        done
    fi
}

history -r ~/.shit_history
tput smcup  # Save terminal screen
prompt
