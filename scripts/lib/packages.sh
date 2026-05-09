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

prepare_cargo_build_env() {
    local cache_root="${XDG_CACHE_HOME:-$HOME/.cache}/mycelium"
    export TMPDIR="${cache_root}/tmp"
    export CARGO_TARGET_DIR="${cache_root}/cargo-target"
    ensure_dir "$TMPDIR"
    ensure_dir "$CARGO_TARGET_DIR"
}

install_tgt_from_git() {
    prepare_cargo_build_env
    if have tgt || [[ -x "$HOME/.cargo/bin/tgt" ]]; then
        return 0
    fi
    log "Installing tgt from upstream git"
    cargo install \
        --git https://github.com/FedericoBruzzone/tgt \
        --locked \
        --no-default-features \
        --features download-tdlib,static \
        tgt || log "cargo install tgt from git failed"
    refresh_path
}

install_starship_with_cargo() {
    prepare_cargo_build_env
    if have starship || [[ -x "$HOME/.cargo/bin/starship" ]]; then
        return 0
    fi
    log "Installing starship via cargo"
    cargo install --locked starship || cargo install starship || log "cargo install starship failed"
    refresh_path
}

install_cargo_packages() {
    local packages=("$@")
    [[ ${#packages[@]} -eq 0 ]] && return 0

    ensure_cargo_toolchain
    prepare_cargo_build_env

    local pkg
    for pkg in "${packages[@]}"; do
        if have "$pkg" || [[ -x "$HOME/.cargo/bin/$pkg" ]]; then
            continue
        fi
        if [[ "$pkg" == "tgt" ]]; then
            install_tgt_from_git
            continue
        fi
        if [[ "$pkg" == "starship" ]]; then
            install_starship_with_cargo
            continue
        fi
        log "Installing $pkg via cargo"
        case "$pkg" in
            yazi)
                cargo install --force yazi-build 2>/dev/null || cargo install --force yazi-build || log "cargo install yazi-build failed"
                cargo install --force --locked yazi-fm yazi-cli 2>/dev/null || cargo install --force yazi-fm yazi-cli || log "cargo install yazi failed"
                ;;
            *)
                cargo install --locked "$pkg" 2>/dev/null || cargo install "$pkg" || log "cargo install $pkg failed"
                ;;
        esac
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
