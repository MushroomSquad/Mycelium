install_packages() {
    local manager="$1"
    shift
    local packages=("$@")
    [[ ${#packages[@]} -eq 0 ]] && return

    log "Installing packages: ${packages[*]}"

    case "$manager" in
        dnf)
            sudo dnf install -y --skip-unavailable "${packages[@]}"
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

ensure_cargo_toolchain() {
    if have cargo; then
        refresh_path
        return 0
    fi

    if have rustup; then
        rustup default stable
        refresh_path
    else
        log "Installing Rust via rustup for cargo-managed packages"
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
        refresh_path
    fi

    have cargo || fail "cargo is required to install optional cargo packages."
}

install_cargo_packages() {
    local packages=("$@")
    [[ ${#packages[@]} -eq 0 ]] && return 0

    ensure_cargo_toolchain

    local pkg
    for pkg in "${packages[@]}"; do
        if have "$pkg" || [[ -x "$HOME/.cargo/bin/$pkg" ]]; then
            continue
        fi
        log "Installing $pkg via cargo"
        cargo install --locked "$pkg" 2>/dev/null || cargo install "$pkg" || log "cargo install $pkg failed"
        refresh_path
    done
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
