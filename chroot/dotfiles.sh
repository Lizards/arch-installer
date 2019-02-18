#!/bin/bash -e


function main() {
    local HOSTNAME=${1}
    local USERNAME=${2}
    local VIRTUALBOX=${3}
    local USER_HOME
    USER_HOME="$(getent passwd "${USERNAME}" | cut -d: -f6)"

    sudo -u "${USERNAME}" mkdir /tmp/arch-system-config
    pushd /tmp/arch-system-config
        sudo -u "${USERNAME}" curl -L https://github.com/Lizards/arch-system-config/tarball/master | tar -xvz --strip-component=1
        sudo -u "${USERNAME}" aur build -d custom  -- --clean --syncdeps --noconfirm --needed
        # Try to install system-specific config based on hostname, falling back to the shared base-config package only
        pacman -Syu --noconfirm "${HOSTNAME}-config" || pacman -Syu --noconfirm base-config
    popd

    pushd "${USER_HOME}"
        sudo -u "${USERNAME}" git clone --recurse-submodules -j8 https://github.com/Lizards/dotfiles
        pushd dotfiles
            echo
            echo "Installing dotfiles..."
            if [ "${VIRTUALBOX}" == "1" ]; then
                # Branches are named after machine's hostname; just do this to check out the virtualbox branch
                HOSTNAME='virtualbox'
            fi
            sudo -u "${USERNAME}" git checkout "${HOSTNAME}" || echo "No branch matching hostname; using master"
            sudo -u "${USERNAME}" make
        popd
    popd
}


main "$@"
