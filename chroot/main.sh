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
    echo -e "127.0.0.1\tlocalhost" >> /etc/hosts
    echo -e "127.0.1.1\t${HOSTNAME}" >> /etc/hosts
}


function install_packages() {
    local HOSTNAME=${1}
    local INSTALL_DOTFILES=${2}
    local INSTALL_IPTABLES=${3}
    local CHROOT_SCRIPT_DIR=${4}
    local USERNAME=${5}
    local VIRTUALBOX=${6}

    # Install the list of packages first, rather than together with the AUR packages after aursync,
    # as some may be dependencies for compiling the AUR packages
    readarray -t packages < <(grep -v '^ *#' < "${CHROOT_SCRIPT_DIR}/packages/arch")
    pacman -Syu --noconfirm --needed "${packages[@]}"

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

    if [ "${INSTALL_IPTABLES}" == "1" ]; then
        iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 22 -j ACCEPT
        iptables-save -f /etc/iptables/iptables.rules
        systemctl enable iptables.service
    fi

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


function configure_virtualbox_guest() {
    echo
    echo "VirtualBox detected"
    pacman -Syu --noconfirm virtualbox-guest-utils
    systemctl enable vboxservice.service
    export DISPLAY=:0
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
    echo "Defaults passwd_timeout=600" >> /etc/sudoers

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

    # TEMPORARY for installation: allow user to run sudo without password
    echo "${USERNAME} ALL=NOPASSWD: ALL" > /etc/sudoers.d/01-installer-pacman
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
        install_packages "${HOSTNAME}" "${INSTALL_DOTFILES:-1}" "${INSTALL_IPTABLES:-1}" "${CHROOT_SCRIPT_DIR}" "${USERNAME}" "${VIRTUALBOX}"
        pause
    fi

    # Cleanup: Remove ability to sudo without password
    rm /etc/sudoers.d/01-installer-pacman
}


main "$@"
