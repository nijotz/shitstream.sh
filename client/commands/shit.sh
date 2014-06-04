#!/bin/bash

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
