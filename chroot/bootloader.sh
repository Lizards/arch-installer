#!/bin/bash -e
# shellcheck source=/dev/null


function generate_bootloader_entry {
    local BOOTLOADER_TITLE=${1}
    local PARTUUID=${2}
    local KERNEL_NAME=${3:-linux}
    read -r -d '' DOC <<- EOF || true  # https://unix.stackexchange.com/a/265151
		title   ${BOOTLOADER_TITLE}
		linux   /vmlinuz-${KERNEL_NAME}
		initrd  /initramfs-${KERNEL_NAME}.img
		options root=PARTUUID=${PARTUUID} rw ipv6.disable=1
	EOF
    echo "${DOC}"
}


function main() {
    local ROOT_PART=${1}
    local INSTALL_LTS_KERNEL=${2}
    # Bootloader titles, use LTS as default if installed
    local BOOTLOADER_TITLE_DEFAULT="Arch"
    local BOOTLOADER_TITLE_LTS="Arch - LTS Kernel"
    local BOOTLOADER_DEFAULT="${BOOTLOADER_TITLE_DEFAULT}" && [[ "${INSTALL_LTS_KERNEL}" == "1" ]] && BOOTLOADER_DEFAULT="${BOOTLOADER_TITLE_LTS}"
    # Get PARTUUID for bootloader entry files
    local PARTUUID # SC2155: Declare and assign separately to avoid masking return values.
    PARTUUID=$(blkid -s PARTUUID -o value "${ROOT_PART}")
    source "${CHROOT_SCRIPT_DIR}/pause.sh"

    # Install systemd-boot and create config
    # please note tabs in the here-doc to support indentation - https://unix.stackexchange.com/questions/76481/cant-indent-heredoc-to-match-nestings-indent
    echo "Installing systemd-boot"
    bootctl install
    cat > /boot/loader/loader.conf <<- EOF
		default ${BOOTLOADER_DEFAULT}
		timeout 5
		editor  0
	EOF

    # Create bootloader entry
    generate_bootloader_entry "${BOOTLOADER_TITLE_DEFAULT}" "${PARTUUID}" > /boot/loader/entries/arch.conf
    pause
    # Optionally install LTS kernel and create a second bootloader entry
    if [ "${INSTALL_LTS_KERNEL}" == "1" ]; then
        echo "Installing long-term support kernel"
        pacman -Syu --noconfirm linux-lts
        generate_bootloader_entry "${BOOTLOADER_TITLE_LTS}" "${PARTUUID}" "linux-lts" > /boot/loader/entries/arch-lts.conf
        pause
    fi
}


main "$@"
