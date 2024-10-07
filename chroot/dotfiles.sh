#!/bin/bash -e


function main() {
    local HOSTNAME=${1}
    local USERNAME=${2}
    local VIRTUALBOX=${3}
    if [ "${VIRTUALBOX}" == "1" ]; then
        # Branches are named after machine's hostname; just do this to check out the virtualbox branches
        HOSTNAME='virtualbox'
    fi
    local USER_HOME
    USER_HOME="$(getent passwd "${USERNAME}" | cut -d: -f6)"

    pushd "${USER_HOME}"
        sudo -u "${USERNAME}" git clone https://github.com/Lizards/arch-system-config
        pushd arch-system-config
            sudo -u "${USERNAME}" git checkout "${HOSTNAME}" || echo "No branch matching hostname ${HOSTNAME}; using master"
            sudo -u "${USERNAME}" aur build -d custom  -- --clean --syncdeps --noconfirm --needed
            # Try to install system-specific config based on hostname, falling back to the shared base-config package only
            pacman -Syu --noconfirm --overwrite "*" "${HOSTNAME}-config" || pacman -Syu --noconfirm --overwrite "*" base-config
        popd

        sudo -u "${USERNAME}" git clone --recurse-submodules -j8 https://github.com/Lizards/dotfiles
        pushd dotfiles
            echo
            echo "Installing dotfiles..."
            sudo -u "${USERNAME}" make
        popd
    popd
}


main "$@"
