#!/bin/bash

while true; do
    ncat --recv-only $1 $2 > /tmp/mp3
    afplay /tmp/mp3
done
