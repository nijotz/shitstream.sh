#!/bin/bash

SHIT_DIR=~/.shitstream
SHIT_PLAYER=""

stream_pid=0
connection_pid=0

# Initialize status messages
status_connection="Not connected"
status_current_mp3="Not streaming"

# Used for setting text color/attributes
nrm=$(tput sgr0)
bld=$(tput bold)
red=$(tput setaf 1)
grn=$(tput setaf 2)
ylw=$(tput setaf 3)
blu=$(tput setaf 4)
mgn=$(tput setaf 5)


# For now just echo, will add verbosity options later
function v {
    echo $*
}

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

function print_text {
    lockfile -1 -r 60 ${SHIT_DIR}/output.lock
    lines=$(tput lines)
    last1=$(( $lines - 2 ))
    last=$(( $lines - 1 ))
    tput xoffc
    tput sc
    tput csr 1 $last1
    tput cup $last1
    echo -e $*
    tput csr 0 $last
    tput rc
    tput xonc
    rm -f ${SHIT_DIR}/output.lock
}

function print_server_text {
    output=$*
    print_text "${blu}Server> ${output}${nrm}"
}

function print_client_text {
    output=$*
    print_text "${grn}Client> ${output}${nrm}"
}

function print_status_bar {
    lockfile -1 -r 60 ${SHIT_DIR}/output.lock

    tput sc  # Save cursor position
    tput cup 0 0  # Move to top left
    tput el  # Clear to end of line

    echo "${grn}[${blu}Server:${nrm} ${status_connection}${grn}][${blu}Song:${nrm} $status_current_mp3${grn}]${nrm}"

    tput rc  # Restore cursor position

    rm -f ${SHIT_DIR}/output.lock
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

    if ! is_connected; then
        print_text "You need to connect first"
        return
    fi

    if is_streaming; then
        print_text "Currently streaming, disconnect first"
        return 1
    fi

    (
        function update_status_bar {
            status_connection=$1
            status_current_mp3=$2
            echo "status_connection=\"$1\"" > ${SHIT_DIR}/toilet
            echo "status_current_mp3=\"$2\"" >> ${SHIT_DIR}/toilet
            print_status_bar
        }

        function identify_mp3 {
            id3info=$(mpg123-id3dump "$1" 2>&1)
            artist=$(echo -e "$id3info" | sed -nr 's/Artist: (.*)/\1/p')
            track=$(echo -e "$id3info" | sed -nr 's/Title: (.*)/\1/p')

            if [ -z "$artist" ] && [ -z "$track" ]; then
                echo "Unidentified song"
            else
                echo $artist - $track
            fi
        }

        function cleanup {
            rm -f ${SHIT_DIR}/toilet
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
            update_status_bar "Playing from $shit_server $shit_port" "$(identify_mp3 ${SHIT_DIR}/mp3)"
            mpg123 ${SHIT_DIR}/mp3 >/dev/null 2>&1 &
            wait $!
            err=$?
        done
    ) &
    stream_pid=$!
}

function command_stop {
    helptext="Stop playing the shit coming from the server"
    helptext="Usage: stop"

    if is_streaming; then
        kill $stream_pid
        wait $stream_pid
        stream_pid=0
        status_connection="Connected to $shit_server $shit_port"
    fi
}

function command_connect {
    helptext="Connect to a stream of shit"
    helptext="Usage: connect <server> <port>"

    if [ -n "$shit_server" ]; then
        command_disconnect
    fi

    print_text "Connecting to $1:$2"
    { exec 3<> /dev/tcp/$1/$2; } 2>/dev/null
    if [ $? -ne 0 ]; then
        print_text 'Connection refused'
        return 1
    fi

    shit_server=$1
    shit_port=$2

    echo -e 'SHIT 1' >&3

    (
        while true; do
            read line <&3
            if [ -n "$line" ]; then
                print_server_text "$line"
            fi
        done
    ) &
    connection_pid=$!

    status_connection="Connected to $shit_server $shit_port"
    print_text "Connected to $1:$2"
}

function is_connected {
    [ "$connection_pid" -eq 0 ] && return 1
    return 0
}

function is_streaming {
    [ "$stream_pid" -eq 0 ] && return 1
    return 0
}

function command_disconnect {
    helptext="Disconnect from current stream of shit"
    helptext="Usage: disconnect"

    if ! is_connected; then
        print_text "Not connected"
        return 1
    fi

    v "Disconnecting from ${shit_server}:${shit_port}"

    if is_streaming; then
        command_stop
    fi

    kill $connection_pid
    wait $connection_pid
    shit_server=""
    shit_port=""
    connection_pid=0

    exec 3<&-

    status_connection="Not connected"
}

function command_shit {
    helptext[0]="Take a shit in the shitstream"
    helptext[1]="Usage: shit [-f file] [-u url]"
    helptext[2]="  file	A local mp3 file to add to the playlist"
    helptext[3]="  url	A URL to a song on a site supported by anything2mp3.com"

    function shit_the_bed {
        print_text "${bld}You shit the bed${nrm}"
        print_text $(printf -- '%s\n' "${helptext[@]:1}")
        return
    }

    # Error message on bad usage
    if [ -z "$*" ]; then shit_the_bed; return; fi
    if [ $# -ne 2 ]; then shit_the_bed; return; fi

    # Can only upload if connected
    if ! is_connected; then
        print_text "Not connected"
        return
    fi

    if [ $1 == -f ]; then
        mp3=$(echo $2 | sed "s!^\~!${HOME}!")

        if [ ! -f $mp3 ]; then
            print_text "File not found: $mp3"
            return
        fi

        echo "shit_mp3" >&3
        echo >&3
        cat $mp3 >&3
        print_client_text "shit_mp3 <data>"
        print_text "Sent mp3 to server"
        return
    fi

    if [ $1 == -u ]; then
        echo "shit_url" >&3
        echo "$2" >&3
        echo >&3
        print_client_text "shit_url $2"
        print_text "Sent URL to stream"
        return
    fi

    shit_the_bed
}

function command_ping {
    helptext="Test connection"

    if ! is_connected; then
        print_text 'Not connected'
        return 1
    fi

    echo -e 'ping\n' >&3
    print_client_text "ping"
}

function command_help {
    helptext="Display help for commands"
    helptext="Usage: help <command> [command2] [command3] ..."

    local command

    if [ -z "$@" ]; then
        for command in $(declare -f | grep ^command_ | sed 's/(). *//'); do
            print_text $(echo $command | sed -r 's/^command_([A-Za-z_]*).*/\1/')
        done
    else
        for command in "$@"; do
            if [ "$(declare -f | grep -c command_$command)" -eq 0 ]; then
                print_text "No help content found for ${bld}${command}${nrm}"
            else
                print_text "${bld}${command}${nrm}"

                # The [][0-9]* will optionally match helptext arrays, all the
                # quoting is to match double or single quotes
                print_text $(
                    declare -f command_$command |
                    grep '[h]elptext[][0-9]*=' |
                    sed 's/^ *[h]elptext[][0-9]*=["'"'"']//g' |
                    sed 's/['"'"'"];//'
                )
            fi
        done
    fi
}

begin
