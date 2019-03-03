#!/bin/bash


function pause() {
    if [ "${PAUSE_BETWEEN_STEPS:-0}" == 1 ]; then
        read -r -p "Press enter to continue"
    fi
}

