#! /bin/bash -e


function main() {
    local REPO_DIR='/var/cache/pacman/custom'
    local REPO_DB="${REPO_DIR}/custom.db.tar"
    local USERNAME=${1}

    # Install dependencies
    pacman -Syu --noconfirm --needed git jq pacutils vifm aria2 parallel expac

    # pacman local repo and aurutils
    # please note tabs in the here-doc to support indentation - https://unix.stackexchange.com/questions/76481/cant-indent-heredoc-to-match-nestings-indent
    cat > /etc/pacman.d/custom <<- EOF
		[options]
		CacheDir = /var/cache/pacman/pkg
		CacheDir = /var/cache/pacman/custom
		CleanMethod = KeepCurrent

		[custom]
		SigLevel = Optional TrustAll
		Server = file:///var/cache/pacman/custom
	EOF
    echo 'Include = /etc/pacman.d/custom' | tee -a /etc/pacman.conf
    sed -i 's/#Color/Color/' /etc/pacman.conf
    install -d "${REPO_DIR}" -o "${USERNAME}"
    sudo -u "${USERNAME}" repo-add "${REPO_DB}"
    pacman -Syy

    # run makepkg as user
    local AURUTILS_BUILD_DIR='/tmp/aurutils'
    sudo -u "${USERNAME}" mkdir "${AURUTILS_BUILD_DIR}"
    sudo -u "${USERNAME}" gpg --recv-keys DBE7D3DD8C81D58D0A13D0E76BC26A17B9B7018A

    pushd "${AURUTILS_BUILD_DIR}"
        sudo -u "${USERNAME}" git clone https://aur.archlinux.org/aurutils.git .
        sudo -u "${USERNAME}" makepkg -s
        local AURUTILS_PKG
        AURUTILS_PKG=$(ls aurutils*.pkg.tar.xz)
        sudo -u "${USERNAME}" mv "${AURUTILS_PKG}" "${REPO_DIR}"
        sudo -u "${USERNAME}" repo-add --new "${REPO_DB}" "${REPO_DIR}/${AURUTILS_PKG}"
    popd

    pacman -Syu --noconfirm aurutils
}


main "$@"
