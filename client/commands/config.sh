#!/bin/bash

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
