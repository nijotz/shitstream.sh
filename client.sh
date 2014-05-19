#!/bin/bash

# Audio programs to use for playing mp3s
audio_programs_Darwin=(afplay)
audio_programs_Linux=(mpg123 mplayer ffplay cvlc)

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
        # TODO: Improve how stream status is passed from the child process
        # The streaming subprocess puts its status strings in /tmp/toilet.
        # Load it for the status bar.
        test -f /tmp/toilet && source /tmp/toilet
        show_status_bar

        # Read input with readline support (-e), ctrl-d will quit
        read -e -p "${mgn}shit${nrm}> " input
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

    # Look for the command by looking for a function named after it
    if ! output=$(declare -f | grep "command_${command} ()"); then
        echo Invalid command: $command
    else
        command_$command $*
    fi
}

function show_status_bar {
    tput sc  # Save cursor position
    tput cup 0 0  # Move to top left
    tput el  # Clear to end of line

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

    for proc in $(jobs -p); do
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
        function cleanup {
            jobs -p | xargs kill
            exit
        }

        trap cleanup SIGINT SIGTERM SIGHUP

        function update_status_bar {
            status_connection=$1
            echo "status_connection=\"$1\"" > /tmp/toilet
            show_status_bar
        }
        while true; do
            output=$(ncat --recv-only $1 $2 2>&1 > /tmp/mp3)
            err=$?
            if [ $err -ne 0 ]; then
                update_status_bar "Connection failure ($output), retrying in 5 seconds..."
                sleep 5 &
                wait $!
            else
                update_status_bar "Connected to $1 $2"
                get_audio_program program
                $program /tmp/mp3 &
                wait $!
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

function command_shit {
    helptext[0]="Take a shit in the shitstream"
    helptext[1]="Usage: shit [-f file] [-u url]"
    helptext[2]="  file	A local mp3 file to add to the playlist"
    helptext[3]="  url	A URL to a song on a site supported by anything2mp3.com"

    function shit_the_bed {
        echo "${bld}You shit the bed${nrm}"
        printf -- '%s\n' "${helptext[@]:1}"
        return
    }

    if [ -z "$*" ]; then shit_the_bed; return; fi
    if [ $# -ne 2 ]; then shit_the_bed; return; fi

    if [ $1 == -f ]; then
        mp3=$(echo $2 | sed "s!^\~!${HOME}!")

        if [ ! -f $mp3 ]; then
            echo "File not found: $mp3"
            return
        fi

        cat $mp3 | ncat 0.0.0.0 8675
        return
    fi

    if [ "$1" == "-u" ]; then
        echo "Eventually..."
        return
    fi

    shit_the_bed
}

function command_help {
    helptext="Display help for commands"
    helptext="Usage: help <command> [command2] [command3] ..."

    local command

    if [ -z "$@" ]; then
        for command in $(declare -f | grep ^command_ | sed 's/(). *//' | sort); do
            echo $command | sed -r 's/^command_([A-Za-z_]*).*/\1/'
        done
    else
        for command in "$@"; do
            if [ "$(declare -f | grep -c command_$command)" -eq 0 ]; then
                echo "No help content found for ${bld}${command}${nrm}"
            else
                echo "${bld}${command}${nrm}"
                declare -f command_$command | grep '[h]elptext=' | sed 's/^ *[h]elptext=["'"'"']//g' | sed 's/['"'"'"];//'
            fi
        done
    fi
}

begin
