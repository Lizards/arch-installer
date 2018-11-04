#!/bin/bash -e


function main () {
    HOSTNAME="${1}"
    USER="${2}"
    
    sudo -u "${USER}" mkdir /tmp/arch-system-config
    
    pushd /tmp/arch-system-config
        sudo -u "${USER}" curl -L https://github.com/Lizards/arch-system-config/tarball/master | tar -xvz --strip-component=1
        sudo -u "${USER}" aurbuild -d custom
        pacman -Syu --noconfirm "${HOSTNAME}-config"
    popd
}


main "$@"
