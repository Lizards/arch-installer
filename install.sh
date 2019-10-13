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


configure_wlan() {
    # Assumes WPA, one wireless interface, and one ethernet interface.
    # Set `WLAN_INTERFACE` and `ETH_INTERFACE` in .config if this doesn't work.
    local WLAN_SSID=${1}
    local WLAN_PASS=${2}
    local WLAN_INTERFACE=${3}
    local ETH_INTERFACE=${4}

    if [ "${WLAN_INTERFACE}" == "0" ]; then
        WLAN_INTERFACE=$(iw dev | awk '$1=="Interface"{print $2}')
    fi
    if [ "${ETH_INTERFACE}" == "0" ]; then
        ETH_INTERFACE=$(ifconfig | grep UP,BROADCAST | cut -f 1 -d :)
    fi

    systemctl stop dhcpcd@"${ETH_INTERFACE}"
    wpa_passphrase "${WLAN_SSID}" "${WLAN_PASS}" > wpa_supplicant.conf
    wpa_supplicant -B -i "${WLAN_INTERFACE}" -c wpa_supplicant.conf
    ip link set "${WLAN_INTERFACE}" up
    dhcpcd "${WLAN_INTERFACE}"
}


function cleanup() {
    umount -R /mnt
    reboot
}


function main() {
    source .config
    source pause.sh

    setfont sun12x22

    if [ "${WLAN_INSTALL:-0}" == "1" ]; then
        if [ -z "${WLAN_SSID}" ] || [ -z "${WLAN_PASS}" ]; then
            # shellcheck disable=SC2016
            echo 'ERROR: Configure variables `WLAN_SSID` and `WLAN_PASS` to install over wifi'
            exit 1
        fi
        configure_wlan "${WLAN_SSID}" "${WLAN_PASS}" "${WLAN_INTERFACE:-0}" "${ETH_INTERFACE:-0}"
        pause
    fi

    setup_partitions "${BOOT_PART}" "${ROOT_PART}" "${SWAP_PART}" "${HOME_PART}"
    pause
    setup_mirrorlist "${COUNTRY:-United States}"
    pause

    pacstrap /mnt base base-devel linux linux-firmware
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
