#!/bin/bash

# Audio programs to use for playing mp3s
audio_programs_Darwin=(afplay)
audio_programs_Linux=(mpg123 mplayer ffplay cvlc)

API_VERSION=1

# Store pid of streaming process
stream_pid=0

# Initialize status messages
status_connection="Not connected"
status_current_mp3="Not connected"

# Used for setting text color/attributes
bld=$(tput bold)
nrm=$(tput sgr0)
grn=$(tput setaf 2)
blu=$(tput setaf 4)
mgn=$(tput setaf 5)

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
        read -e -p "${mgn}shit${nrm}> " input
        # TODO: Improve how stream status is passed from the child process
        test -f /tmp/toilet && source /tmp/toilet
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

    history -s $command $*  # Append command to history
}

function show_status_bar {
    tput sc  # Save cursor position
    tput cup 0 0  # Move to top left

    echo "${grn}[${blu}Server:${nrm} ${status_connection}${grn}][${blu}Song:${nrm} $status_current_mp3${grn}]${nrm}"

    tput rc  # Restore cursor position
}

function begin {
    command_loadcfg
    history -r ~/.shit_history  # Load history file for readline
    tput smcup  # Save terminal screen
    prompt
}

function command_quit {
    helptext="duh."

    for proc in $(jobs -p)
    do
        kill $proc
        wait $proc
    done

    command_savecfg
    history -w ~/.shit_history  # Write history file
    tput rmcup  # Restore original terminal output
    rm -f /tmp/toilet
    exit
}
trap command_quit SIGINT SIGTERM SIGHUP EXIT

function command_loadcfg {
    helptext="Load configuration values from a file"
    helptext="Usage: loadcfg [cfgfile]"
    helptext="  cfgfile	Config file to load (default: ~/.shitstream)"
    source ${1:-~/.shitstream}
}

function command_savecfg {
    helptext="Save configuration values to a file"
    helptext="Usage: savecfg [cfgfile]"
    helptext="  cfgfile	Config file to load (default: ~/.shitstream)"

    set | grep ^SHIT_ > ~/.shitstream
}

function command_connect {
    helptext="Connect to a stream of shit"
    helptext="Usage: connect <server> <port>"

    if [ $stream_pid -ne 0 ]; then
        echo "Currently streaming, disconnect first"
        return
    fi

    (
        trap exit SIGINT SIGTERM SIGHUP
        exec 2>/dev/null

        function update_status_bar {
            status_connection=$1
            echo "status_connection=\"$1\"" > /tmp/toilet
            show_status_bar
        }
        while true; do
            ncat --recv-only $1 $2 > /tmp/mp3
            if [ $? ]; then
                update_status_bar "Connection refused, retrying in 5 seconds..."
                sleep 5
            else
                update_status_bar "Connected to $1 $2"
                get_audio_program program
                $program /tmp/mp3
            fi
        done
    ) &

    stream_pid=$!
}

function command_disconnect {
    helptext="Disconnect from current stream of shit"
    helptext="Usage: disconnect"

    if [ $stream_pid -ne 0 ]; then
        kill $stream_pid
        stream_pid=0
        rm -f /tmp/toilet
    else
        echo Not currently streaming
    fi

    status_connection="Not connected"
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

begin
