#!/bin/bash

function startup_config {
    command_loadcfg ${SHIT_DIR}/config
}

function cleanup_config {
    command_savecfg
}

function command_loadcfg {
    helptext="Load configuration values from a file"
    helptext="Usage: loadcfg [cfgfile]"
    helptext="  cfgfile	Config file to load (default: ~/.shitstream/config)"

    cfg=${1:-${SHIT_DIR}/config}
    [ -f "$cfg" ] && source $cfg
}

function command_savecfg {
    helptext="Save configuration values to a file"
    helptext="Usage: savecfg [cfgfile]"
    helptext="  cfgfile	Config file to load (default: ~/.shitstream/config)"

    mkdir -p ${SHIT_DIR}
    set | grep ^SHIT_ > ${SHIT_DIR}/config
}
