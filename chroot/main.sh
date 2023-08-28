#! /bin/bash -ex
# shellcheck source=/dev/null


function configure_localtime() {
    local TIMEZONE=${1}
    echo "Configuring localtime using ${TIMEZONE}..."

    # timezone and time sync
    ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
    hwclock --systohc

    # locale
    sed -i 's/^#\(en_US\.UTF-8\)/\1/g' /etc/locale.gen
    locale-gen
    echo "LANG=en_US.UTF-8" > /etc/locale.conf
}


function configure_hostname() {
    local HOSTNAME=${1}
    echo "${HOSTNAME}" > /etc/hostname
    sed -i "8i 127.0.1.1\\t$HOSTNAME.localdomain\\t$HOSTNAME" /etc/hosts
}


function install_packages() {
    local HOSTNAME=${1}
    local INSTALL_DOTFILES=${2}
    local CHROOT_SCRIPT_DIR=${3}
    local USERNAME=${4}
    local VIRTUALBOX=${5}

    # Install the list of packages first, rather than together with the AUR packages after aursync,
    # as some may be dependencies for compiling the AUR packages
    readarray -t packages < "${CHROOT_SCRIPT_DIR}/packages/arch"
    pacman -Syu --noconfirm --needed "${packages[@]}"

    # Jupyter Notebook: https://wiki.archlinux.org/index.php/Jupyter#Installation
    jupyter nbextension enable --py --sys-prefix widgetsnbextension || true

    # Import GPG keys for AUR packages
    grep -v '^ *#' < "${CHROOT_SCRIPT_DIR}/packages/gpg-keys" | while IFS= read -r key
    do
        sudo -u "${USERNAME}" gpg --recv-keys "${key}"
    done
    # Install AUR packages
    grep -v '^ *#' < "${CHROOT_SCRIPT_DIR}/packages/aur" | while IFS= read -r package
    do
        sudo -u "${USERNAME}" aur sync --no-view --no-confirm "${package}"
        # Packages compiled from source aren't automatically installed through `aur sync` (this impacts Polybar)
        if ! pacman -Qs "${package}" > /dev/null ; then pacman -Syu --noconfirm "${package}"; fi
    done

    if [ "${INSTALL_DOTFILES}" == "1" ]; then
        # Install dotfiles and configs from `arch-system-config` repo (package named after hostname)
        bash "${CHROOT_SCRIPT_DIR}/dotfiles.sh" "${HOSTNAME}" "${USERNAME}" "${VIRTUALBOX}"
    fi

    # Add given user to groups provided by installed packages
    grep -v '^ *#' < "${CHROOT_SCRIPT_DIR}/packages/groups" | while IFS= read -r group
    do
        usermod -aG "${group}" "${USERNAME}"
    done

    # Enable systemd daemons
    start_services "${USERNAME}"
}


function install_bluetooth() {
    local HOSTNAME=${1}
    sudo -u "${USERNAME}" mkdir /tmp/arch-bluetooth-pulseaudio
    pushd /tmp/arch-bluetooth-pulseaudio
        sudo -u "${USERNAME}" curl -L https://github.com/Lizards/arch-bluetooth-pulseaudio/tarball/master | tar -xvz --strip-component=1
        sudo -u "${USERNAME}" aur build -d custom -- --clean --syncdeps --noconfirm --needed
        pacman -Syu --noconfirm arch-bluetooth-pulseaudio
    popd
}


function configure_virtualbox_guest() {
    echo
    echo "VirtualBox detected"
    pacman -Syu --noconfirm virtualbox-guest-utils
    systemctl enable vboxservice.service
}


function start_services() {
    local USERNAME=${1}
    # system services
    grep -v '^ *#' < "${CHROOT_SCRIPT_DIR}/services/system" | while IFS= read -r service
    do
        systemctl enable "${service}"
    done
    # user services
    grep -v '^ *#' < "${CHROOT_SCRIPT_DIR}/services/user" | while IFS= read -r service
    do
        sudo -u "${USERNAME}" systemctl --user enable "${service}"
    done
}


setup_user() {
    local USERNAME=${1}
    local PASS=${2}
    local USER_GROUPS=${3}
    local ROOT_PASS=${4}

    # Set root password
    echo "Setting root password"
    usermod --password "${ROOT_PASS}" root

    # Allow wheel group to sudo
    sed -i 's/# \(%wheel ALL=(ALL:ALL) ALL\)/\1/' /etc/sudoers

    # Create user
    echo "Creating user ${USERNAME}"
    useradd -m -G "${USER_GROUPS}" "${USERNAME}"
    echo "${USERNAME}:${PASS}" | chpasswd
}


function main() {
    export CHROOT_SCRIPT_DIR="${1:-/usr/local/lib/bootstrap}"
    ! grep -q "innotek GmbH" /sys/class/dmi/id/sys_vendor
    local VIRTUALBOX=$?

    source "${CHROOT_SCRIPT_DIR}/.config"
    source "${CHROOT_SCRIPT_DIR}/pause.sh"

    # https://wiki.archlinux.org/index.php/installation_guide#Time_zone
    configure_localtime "${TIMEZONE:-US/Eastern}"
    pause

    # https://wiki.archlinux.org/index.php/installation_guide#Network_configuration
    configure_hostname "${HOSTNAME}"
    pause

    # https://wiki.archlinux.org/index.php/Systemd-boot
    # shellcheck disable=SC2153
    bash "${CHROOT_SCRIPT_DIR}/bootloader.sh" "${ROOT_PART}" "${INSTALL_LTS_KERNEL:-0}"
    pause

    setup_user "${USERNAME}" "${PASS}" "${USER_GROUPS:-wheel,optical,audio,video,lp}" "${ROOT_PASS}"
    pause

    # Install aurutils and configure local 'custom' database
    bash "${CHROOT_SCRIPT_DIR}/aurutils.sh" "${USERNAME}"
    pause

    if [ "${VIRTUALBOX}" == "1" ]; then
        # Install vbox guest packages regardless of `INSTALL_PACKAGES` setting
        configure_virtualbox_guest
        pause
    fi
    if [ "${INSTALL_PACKAGES:-1}" == "1" ]; then
        # install aurutils, set up local pacman database,
        # install all packages, start services,
        # add user to groups provided by packages,
        # install configs from `arch-system-config` repo, and install dotfiles from `dotfiles` repo
        install_packages "${HOSTNAME}" "${INSTALL_DOTFILES:-1}" "${CHROOT_SCRIPT_DIR}" "${USERNAME}" "${VIRTUALBOX}"
        pause
    fi
    if [ "${INSTALL_BLUETOOTH:-1}" == "1" ]; then
        install_bluetooth "${USERNAME}"
    fi
}


main "$@"
