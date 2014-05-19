#!/bin/bash

audio_programs_Darwin=(afplay)
audio_programs_Linux=(mpg123 mplayer ffplay cvlc)

API_VERSION=1

shit_pid=0

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
        read -e -p 'shit> ' input
        handle_input $input
    done
}

function handle_input {
    command=$1
    shift
    if ! output=$(set | grep "command_${command} ()"); then
        echo Invalid command: $command
    else
        command_$command $*
    fi
}

function command_connect {
    helptext="Connect to a stream of shit"
    helptext=
    helptext="Usage: connect <server> <port>"

    (while true; do
        ncat --recv-only $1 $2 > /tmp/mp3
        get_audio_program program
        $program /tmp/mp3
    done) &
    shit_pid=$!
}

function command_help {
    helptext="Display help for commands"
    helptext="Usage: help <command> [command2] [command3] ..."

    if [ -z "$@" ]; then
        for command in $(set | grep ^command_ | sed 's/(). *//'); do
            echo $command | sed -r 's/^command_([A-Za-z_]*).*/\1/'
        done
    else
        for command in "$@"; do
            bold=`tput bold`
            normal=`tput sgr0`
            echo "${bold}${command}${normal}"
            declare -f command_$command | grep '[h]elptext=' | sed 's/^ *[h]elptext=["'"'"']//g' | sed 's/['"'"'"];//'
        done
    fi
}

prompt
