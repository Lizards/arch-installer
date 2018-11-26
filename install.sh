#! /bin/bash -e
# shellcheck source=/dev/null


function setup_partitions() {
    local BOOT_PART=${1}
    local ROOT_PART=${2}
    local SWAP_PART=${3}
    local HOME_PART=${4}

    echo "Mounting / from ${ROOT_PART}"
    mount "${ROOT_PART}" /mnt

    echo "Mounting boot partition from ${BOOT_PART}"
    mkdir -p /mnt/boot
    mount "${BOOT_PART}" /mnt/boot

    if [ -n "${SWAP_PART}" ]; then
        echo "Enabling swap partition at ${SWAP_PART}"
        swapon --discard "${SWAP_PART}"
    fi

    if [ -n "${HOME_PART}" ]; then
        echo "Mounting home partition from ${HOME_PART}"
        mkdir -p /mnt/home
        mount "${HOME_PART}" /mnt/home
    fi
}


function setup_mirrorlist() {
    local COUNTRY=${1}

    echo "Setting up mirrorlist"
    pacman -Sy --noconfirm reflector
    reflector --country "${COUNTRY}" --protocol https --latest 10 --age 12 --sort rate --save /etc/pacman.d/mirrorlist
    cat /etc/pacman.d/mirrorlist
}


function run_chroot() {
    local CHROOT_SCRIPT_DIR=${1}

    mkdir -p "/mnt${CHROOT_SCRIPT_DIR}"
    mv chroot/* "/mnt${CHROOT_SCRIPT_DIR}"
    cp .config "/mnt${CHROOT_SCRIPT_DIR}"
    cp pause.sh "/mnt${CHROOT_SCRIPT_DIR}"

    arch-chroot /mnt bash "${CHROOT_SCRIPT_DIR}/main.sh" "${CHROOT_SCRIPT_DIR}"

    rm -rf "/mnt${CHROOT_SCRIPT_DIR:?}"
}


function cleanup() {
    umount -R /mnt
    reboot
}


function main() {
    source .config
    source pause.sh

    setfont sun12x22

    setup_partitions "${BOOT_PART}" "${ROOT_PART}" "${SWAP_PART}" "${HOME_PART}"
    pause
    setup_mirrorlist "${COUNTRY:-United States}"
    pause

    pacstrap /mnt base base-devel
    pause

    echo "Generating /etc/fstab..."
    genfstab -U /mnt >> /mnt/etc/fstab
    cat /mnt/etc/fstab
    pause

    run_chroot "${CHROOT_SCRIPT_DIR:-/usr/local/lib/bootstrap}"

    echo "Done!"
    pause

    cleanup
}


main
