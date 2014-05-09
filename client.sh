#!/bin/bash

audio_programs_Darwin=(afplay)
audio_programs_Linux=(aplay play cvlc mplayer ffplay)

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

while true; do
    ncat --recv-only $1 $2 > /tmp/mp3
    get_audio_program program
    $program /tmp/mp3
done
