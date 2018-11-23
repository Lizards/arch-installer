#!/bin/bash -e


function main() {
    HOSTNAME="${1}"
    USERNAME="${2}"
    USER_HOME="$(getent passwd "${USERNAME}" | cut -d: -f6)"
    
    sudo -u "${USERNAME}" mkdir /tmp/arch-system-config
    pushd /tmp/arch-system-config
        sudo -u "${USERNAME}" curl -L https://github.com/Lizards/arch-system-config/tarball/master | tar -xvz --strip-component=1
        sudo -u "${USERNAME}" aurbuild -d custom
        pacman -Syu --noconfirm "${HOSTNAME}-config"
    popd

    pushd "${USER_HOME}"
        sudo -u "${USERNAME}" git clone --recurse-submodules -j8 https://github.com/Lizards/dotfiles
        pushd dotfiles
            sudo -u "${USERNAME}" make
        popd
    popd
}


main "$@"
