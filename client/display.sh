#!/bin/bash

# Used for setting text color/attributes
export nrm=$(tput sgr0)
export bld=$(tput bold)
export red=$(tput setaf 1)
export grn=$(tput setaf 2)
export ylw=$(tput setaf 3)
export blu=$(tput setaf 4)
export mgn=$(tput setaf 5)

# Initialize status messages
status_connection="Not connected"
status_current_mp3="Not streaming"

function startup_display {
    lockclear "${SHIT_DIR}/output.lock"
    rm -f "${SHIT_DIR}/toilet"
}

function cleanup_display {
    lockclear "${SHIT_DIR}/output.lock"
}

function print_text {

    #log DEBUG "Acquiring lockfile for screen output"
    lockfile -t 0.1 -r 60 "${SHIT_DIR}/output.lock"

    lines=$(tput lines)
    last1=$(( lines - 2 ))
    last=$(( lines - 1 ))

    tput xoffc || true
    tput sc
    tput csr 1 $last1
    tput cup $last1

    echo -e "$*"
    log DEBUG "Printed text: $*"

    tput csr 0 $last
    tput rc
    tput xonc || true

    lockclear "${SHIT_DIR}/output.lock"
    #log DEBUG "Removed lockfile for screen output"
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
    lockfile -t 0.1 -r 60 "${SHIT_DIR}/output.lock"

    tput sc  # Save cursor position
    tput cup 0 0  # Move to top left
    tput el  # Clear to end of line

    echo "${grn}[${blu}Server:${nrm} ${status_connection}${grn}][${blu}Song:${nrm} $status_current_mp3${grn}]${nrm}"

    tput rc  # Restore cursor position

    lockclear "${SHIT_DIR}/output.lock"
}
