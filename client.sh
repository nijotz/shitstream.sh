#!/bin/bash

SHIT_DIR=~/.shitstream
SHIT_PLAYER=""

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

    if [ -n "$SHIT_PLAYER" ]; then
        eval $reult=$'$SHIT_PLAYER'
        return
    fi

    # Audio programs to use for playing mp3s
    audio_programs_Darwin=(mpg123 afplay)
    audio_programs_Linux=(mpg123 mplayer ffplay cvlc)

    os=$(uname)
    programs_var=audio_programs_$os
    programs=${!programs_var}
    for _program in ${programs[@]}; do
        whichprogram=$(which $_program)
        extstatus=$?
        if [ ! $exitstatus ]; then
            eval $result=$'$whichprogram'
            return
        fi
    done
}

function prompt {
    while true; do
        # TODO: Improve how stream status is passed from the child process The
        # streaming subprocess puts its status strings in toilet.  Load it for
        # the status bar.
        test -f ${SHIT_DIR}/toilet && source ${SHIT_DIR}/toilet
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

function begin {
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
    command_loadcfg ${SHIT_DIR}/config
    history -r ${SHIT_DIR}/history  # Load history file for readline
    tput smcup  # Save terminal screen
    tput clear  # Clear screen
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
    tput rmcup  # Restore original terminal output
    history -w ${SHIT_DIR}/history  # Write history file
    exit
}
trap command_quit SIGINT SIGTERM SIGHUP EXIT

function command_loadcfg {
    helptext="Load configuration values from a file"
    helptext="Usage: loadcfg [cfgfile]"
    helptext="  cfgfile	Config file to load (default: ~/.shitstream/config)"
    source ${1:-${SHIT_DIR}/config}
}

function command_savecfg {
    helptext="Save configuration values to a file"
    helptext="Usage: savecfg [cfgfile]"
    helptext="  cfgfile	Config file to load (default: ~/.shitstream/config)"

    mkdir -p ${SHIT_DIR}
    set | grep ^SHIT_ > ${SHIT_DIR}/config
}

function command_play {
    helptext="Play some shit that's on the server"
    helptext="Usage: play"

    if [ -z "$shit_server" ]; then
        echo "You need to connect first"
        return
    fi

    if [ $stream_pid -ne 0 ]; then
        echo "Currently streaming, disconnect first"
        return
    fi

    (
        function update_status_bar {
            status_connection=$1
            echo "status_connection=\"$1\"" > ${SHIT_DIR}/toilet
            show_status_bar
        }

        function cleanup {
            for job in $(jobs -p); do
                kill $job
                wait $job
            done
        }
        trap cleanup SIGINT SIGTERM SIGHUP EXIT

        err=0
        while [ $err -eq 0 ]; do
            exec 4<> /dev/tcp/$shit_server/$shit_port
            echo -e "SHIT 1\nshit_on_me\n" >&4
            read length <&4
            dd bs=1 count=$length <&4 > ${SHIT_DIR}/mp3 2>/dev/null
            exec 4<&-
            update_status_bar "Playing from $shit_server $shit_port"
            get_audio_program program
            $program ${SHIT_DIR}/mp3 >/dev/null 2>&1 &
            wait $!
            err=$?
        done
    ) &
    stream_pid=$!
}

function command_stop {
    helptext="Stop playing the shit coming from the server"
    helptext="Usage: stop"

    if [ $stream_pid -ne 0 ]; then
        kill $stream_pid
        wait $stream_pid
        stream_pid=0
        status_connection="Connected to $shit_server $shit_port"
    fi
}

function command_connect {
    helptext="Connect to a stream of shit"
    helptext="Usage: connect <server> <port>"

    shit_server=$1
    shit_port=$2

    exec 3<> /dev/tcp/$shit_server/$shit_port
    echo -e 'SHIT 1' >&3
    status_connection="Connected to $shit_server $shit_port"
}

function command_disconnect {
    helptext="Disconnect from current stream of shit"
    helptext="Usage: disconnect"

    v "Disconnecting"

    if [ $stream_pid -ne 0 ]; then
        command_stop
    fi

    shit_server=""
    shit_port=""
    exec 3<&-

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
    if [ -z "$shit_server" ]; then
        echo "Not connected"
        return
    fi

    if [ $1 == -f ]; then
        mp3=$(echo $2 | sed "s!^\~!${HOME}!")

        if [ ! -f $mp3 ]; then
            echo "File not found: $mp3"
            return
        fi

        echo "shit_mp3" >&3
        echo >&3
        cat $mp3 >&3
        echo "Sent MP3 to stream"
        return
    fi

    if [ $1 == -u ]; then
        echo "shit_url" >&3
        echo "$2" >&3
        echo >&3

        read line <&3
        while [ -n "$line" ]; do
            echo $line
            read line <&3
        done
        return
    fi

    shit_the_bed
}

function command_ping {
    helptext="Test connection"

    echo -e 'ping\n' >&3
    read line <&3
    while [ -n "$line" ]; do
        echo $line
        read line <&3
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
