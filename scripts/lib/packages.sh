install_packages() {
    local manager="$1"
    shift
    local packages=("$@")
    [[ ${#packages[@]} -eq 0 ]] && return

    log "Installing packages: ${packages[*]}"

    case "$manager" in
        dnf)
            sudo dnf install -y "${packages[@]}"
            ;;
        apt)
            sudo apt-get update
            sudo apt-get install -y "${packages[@]}"
            ;;
        pacman)
            sudo pacman -Sy --noconfirm "${packages[@]}"
            ;;
        zypper)
            sudo zypper --non-interactive install "${packages[@]}"
            ;;
        brew)
            brew install "${packages[@]}"
            ;;
        *)
            fail "No supported package manager found. Install dependencies manually."
            ;;
    esac
}

install_zellij_with_cargo() {
    if have zellij || [[ -x "$HOME/.cargo/bin/zellij" ]]; then
        refresh_path
        return
    fi

    have cargo || fail "cargo is required to install zellij."
    log "Installing zellij with cargo"
    OPENSSL_NO_VENDOR=1 cargo install --locked zellij || cargo install --locked zellij
    refresh_path
    have zellij || [[ -x "$HOME/.cargo/bin/zellij" ]] || fail "zellij install completed but binary is still unavailable."
}

ensure_chezmoi() {
    have chezmoi && return
    log "Installing chezmoi"
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
    refresh_path
    have chezmoi || fail "chezmoi install failed"
}
