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


# For now just echo, will add verbosity options later
function v {
    echo $*
}

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
    tput cup `tput lines` 0  # Move cursor to last line, first column
    prompt
}

function command_quit {
    helptext="duh."

    if [ $stream_pid -ne 0 ]; then
        command_disconnect
    fi

    pkill -P $$

    command_savecfg
    history -w ~/.shit_history  # Write history file
    tput rmcup  # Restore original terminal output
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
            v "Cleaning up streaming process"
            for proc in $(jobs -p); do
                v "Killing $proc"
                kill $proc
                wait $proc
            done
        }
        trap cleanup SIGINT SIGTERM SIGHUP

        function update_status_bar {
            status_connection=$1
            echo "status_connection=\"$1\"" > /tmp/toilet
            show_status_bar
        }

        err=0
        while [ "$err" -eq 0 ]; do
            proto="SHIT 1\nshit_on_me\n\n"
            state="start"
            while [ $state != "finished" ]; do
                if [ $state == "start" ]; then
                    echo -e $proto
                    state="streaming"
                elif [ $state == "streaming" ]; then
                    size=$(head -n 1 /tmp/mp3)
                    size=$(( $size + $( echo $size | wc -c ) ))
                    if [ $size -eq $(wc -c < /tmp/mp3) ]; then
                        state="finished"
                        tail -n +2 /tmp/mp3 > /tmp/newmp3
                        mv /tmp/newmp3 /tmp/mp3
                    else
                        sleep 1
                    fi
                fi
            done | ncat $1 $2 2>&1 > /tmp/mp3

            err=$?
            if [ $err -ne 0 ]; then
                update_status_bar "Connection failure, retrying in 5 seconds..."
                sleep 5 &
                wait $!
            else
                update_status_bar "Connected to $1 $2"
                get_audio_program program
                $program /tmp/mp3 &
                wait $!
                err=$?
            fi
        done
    ) &
    stream_pid=$!

    shit_server=$1
    shit_port=$2

    rm -f /tmp/shit.fifo.in
    rm -f /tmp/shit.fifo.out
    mkfifo /tmp/shit.fifo.in
    mkfifo /tmp/shit.fifo.out
    (
        function cleanup {
            v "Cleaning up connection process"
            for proc in $(jobs -p); do
                v "Killing $proc"
                kill $proc
                wait $proc
            done
        }
        trap cleanup SIGINT SIGTERM SIGHUP
        while true; do
            cat /tmp/shit.fifo.in | tee | grep '^DONE$' && exit
        done | ncat $1 $2 > /tmp/shit.fifo.out
    ) &
    connection_pid=$!
    echo 'SHIT 1\n' > /tmp/shit.fifo.in
}

function command_disconnect {
    helptext="Disconnect from current stream of shit"
    helptext="Usage: disconnect"

    v "Disconnecting"
    if [ $stream_pid -ne 0 ]; then
        v "Killing streaming process $stream_pid"
        kill $stream_pid

        v "Killing connection process $connection_pid"
        kill $connection_pid
        echo DONE > /tmp/shit.fifo.in

        v "Cleaning up tmp files"

        stream_pid=0
        connection_pid=0
        shit_server=""
        shit_port=""

        rm -f /tmp/toilet
        rm -f /tmp/shit.fifo.in
        rm -f /tmp/shit.fifo.out
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

    # Error message on bad usage
    if [ -z "$*" ]; then shit_the_bed; return; fi
    if [ $# -ne 2 ]; then shit_the_bed; return; fi

    # Can only upload if connected
    if [ $stream_pid -eq 0 ]; then
        echo "Not connected, you gotta be in the stream with everyone else to shit in it"
        return
    fi

    if [ $1 == -f ]; then
        mp3=$(echo $2 | sed "s!^\~!${HOME}!")

        if [ ! -f $mp3 ]; then
            echo "File not found: $mp3"
            return
        fi

        cat $mp3 | ncat $shit_server 8675 # TODO: fix hard-coded port $shit_port
        echo "Sent MP3 to stream"
        return
    fi

    if [ $1 == -u ]; then
        echo $2 | ncat $shit_server 8675 # TODO: $shit_port
        echo "Sent URL to stream"
        return
    fi

    shit_the_bed
}

function command_hi {
    helptext="Test connection"

    echo -e 'hi\n' > /tmp/shit.fifo.in
    read line < /tmp/shit.fifo.out
    while [ -n "$line" ]; do
        echo $line
        read line < /tmp/shit.fifo.out
    done
}

function command_help {
    helptext="Display help for commands"
    helptext="Usage: help <command> [command2] [command3] ..."

    local command

    if [ -z "$@" ]; then
        for command in $(declare -f | grep ^command_ | sed 's/(). *//'); do
            echo $command | sed -r 's/^command_([A-Za-z_]*).*/\1/'
        done
    else
        for command in "$@"; do
            if [ "$(declare -f | grep -c command_$command)" -eq 0 ]; then
                echo "No help content found for ${bld}${command}${nrm}"
            else
                echo "${bld}${command}${nrm}"

                # The [][0-9]* will optionally match helptext arrays, all the
                # quoting is to match double or single quotes
                declare -f command_$command |
                    grep '[h]elptext[][0-9]*=' |
                    sed 's/^ *[h]elptext[][0-9]*=["'"'"']//g' |
                    sed 's/['"'"'"];//'
            fi
        done
    fi
}

begin
