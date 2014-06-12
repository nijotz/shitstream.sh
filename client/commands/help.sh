#!/bin/bash

function command_help {
    helptext="Display help for commands" # shellcheck disable=SC2034
    helptext="Usage: help <command> [command2] [command3] ..." # shellcheck disable=SC2034

    local command

    if [ -z "$@" ]; then
        for command in $(declare -f | grep ^command_ | sed 's/(). *//'); do
            print_text "$(echo "$command" | sed -r 's/^command_([A-Za-z_]*).*/\1/')"
        done
    else
        for command in "$@"; do
            if [ "$(declare -f | grep -c command_"$command")" -eq 0 ]; then
                print_text "No help content found for ${bld}${command}${nrm}"
            else
                print_text "${bld}${command}${nrm}"

                # The [][0-9]* will optionally match helptext arrays, all the
                # quoting is to match double or single quotes
                # shellcheck disable=SC2046
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
