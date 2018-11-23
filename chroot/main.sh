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
    local CHIPSET=${1}
    local HOSTNAME=${2}
    local INSTALL_SYSTEM_CONFIGS=${3}
    local CHROOT_SCRIPT_DIR=${4}
    local USERNAME=${5}

    # Install the list of packages first, rather than together with the AUR packages after aursync,
    # as some may be dependencies for compiling the AUR packages
    readarray -t packages < "${CHROOT_SCRIPT_DIR}/packages/arch"
    # Install microcode package & stuff from packages/arch
    pacman -Syu --noconfirm "${CHIPSET}-ucode" "${packages[@]}"
    # Special snowflake Sublime Text
    curl -O https://download.sublimetext.com/sublimehq-pub.gpg && pacman-key --add sublimehq-pub.gpg && pacman-key --lsign-key 8A8F901A && rm sublimehq-pub.gpg
    echo -e "\\n[sublime-text]\\nServer = https://download.sublimetext.com/arch/stable/x86_64" | tee -a /etc/pacman.conf
    pacman -Syu --noconfirm sublime-text

    # Install aurutils and configure local 'custom' database
    bash "${CHROOT_SCRIPT_DIR}/aurutils.sh" "${USERNAME}"

    # Install AUR packages
    grep -v '^ *#' < "${CHROOT_SCRIPT_DIR}/packages/aur" | while IFS= read -r package
    do
        sudo -u "${USERNAME}" aursync --no-view --no-confirm "${package}"
        # Packages compiled from source aren't automatically installed through aursync (this impacts Polybar)
        if ! pacman -Qs "${package}" > /dev/null ; then pacman -S --noconfirm "${package}"; fi
    done

    if [ "${INSTALL_SYSTEM_CONFIGS}" == "1" ]; then
        # Install dotfiles and configs from `arch-system-config` repo (package named after hostname)
        bash "${CHROOT_SCRIPT_DIR}/arch-system-config.sh" "${HOSTNAME}" "${USERNAME}"
    fi

    # Add given user to groups provided by installed packages
    grep -v '^ *#' < "${CHROOT_SCRIPT_DIR}/packages/groups" | while IFS= read -r group
    do
        usermod -aG "${group}" "${USERNAME}"
    done

    # Enable systemd daemons
    start_services "${USERNAME}"
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


function configure_bootloader() {
    local ROOT_PART=${1}
    local CHIPSET=${2}

    # please note tabs in the here-doc to support indentation - https://unix.stackexchange.com/questions/76481/cant-indent-heredoc-to-match-nestings-indent
    bootctl install
    cat > /boot/loader/loader.conf <<- EOF
		default Arch
		timeout 5
		editor  0
	EOF

    local PARTUUID
    PARTUUID=$(blkid -s PARTUUID -o value "${ROOT_PART}")
    cat > /boot/loader/entries/arch.conf <<- EOF
		title   Arch
		linux   /vmlinuz-linux
		initrd  /${CHIPSET}-ucode.img
		initrd  /initramfs-linux.img
		options root=PARTUUID=${PARTUUID} rw ipv6.disable=1
	EOF
}


setup_user() {
    local USERNAME=${1}
    local PASS=${2}

    # Set root password
    echo "Set root password:"
    passwd

    # Allow wheel group to sudo
    sed -i 's/# \(%wheel ALL=(ALL) ALL\)/\1/' /etc/sudoers

    # Create user
    echo "Creating user ${USERNAME}"
    useradd -m -G wheel,optical,audio,video,lp "${USERNAME}"
    echo "${USERNAME}:${PASS}" | chpasswd
}


function main() {
    local CHROOT_SCRIPT_DIR="${1:-/usr/local/lib/bootstrap}"
    source "${CHROOT_SCRIPT_DIR}/.config"

    configure_localtime "${TIMEZONE}"
    configure_hostname "${HOSTNAME}"
    configure_bootloader "${ROOT_PART}" "${CHIPSET}"
    setup_user "${USERNAME}" "${PASS}"
    # install aurutils, set up local pacman database,
    # install all packages, and install configs from `arch-system-config` repo,
    # and start services
    install_packages "${CHIPSET}" "${HOSTNAME}" "${INSTALL_SYSTEM_CONFIGS}" "${CHROOT_SCRIPT_DIR}" "${USERNAME}"
}


main "$@"
