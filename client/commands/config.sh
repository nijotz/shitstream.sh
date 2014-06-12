#!/bin/bash

function startup_config {
    command_loadcfg "${SHIT_DIR}/config"
}

function cleanup_config {
    command_savecfg
}

function command_loadcfg {
    helptext="Load configuration values from a file" # shellcheck disable=SC2034
    helptext="Usage: loadcfg [cfgfile]" # shellcheck disable=SC2034
    helptext="  cfgfile	Config file to load (default: ~/.shitstream/config)" # shellcheck disable=SC2034

    cfg=${1:-${SHIT_DIR}/config}
    [ -f "$cfg" ] && source "$cfg"
}

function command_savecfg {
    helptext="Save configuration values to a file" # shellcheck disable=SC2034
    helptext="Usage: savecfg [cfgfile]" # shellcheck disable=SC2034
    helptext="  cfgfile	Config file to load (default: ~/.shitstream/config)" # shellcheck disable=SC2034

    mkdir -p "${SHIT_DIR}"
    set | grep ^SHIT_ > "${SHIT_DIR}/config"
}
