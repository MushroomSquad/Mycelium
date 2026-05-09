profile_install_required() {
    install_packages dnf \
        neovim btop nnn newsboat neomutt git htop ripgrep fd-find fzf \
        w3m lynx yt-dlp dnf-plugins-core gcc gcc-c++ make rust cargo golang \
        perl-IPC-Cmd perl-FindBin perl-File-Compare perl-File-Copy \
        perl-Time-Piece perl-Text-Template openssl-devel pkgconf-pkg-config \
        wireplumber pavucontrol alsa-utils tlp powertop brightnessctl \
        NetworkManager-tui fastfetch du-dust dua-cli bat eza zoxide jq yq starship \
        ncdu tmux terminus-fonts-console terminus-fonts

    if ! have lazygit; then
        sudo dnf copr enable dejan/lazygit -y
        sudo dnf install -y lazygit
    fi

    install_zellij_with_cargo
}

profile_optional_catalog() {
    cat <<'EOF'
ops-pack|Ops pack - k9s, lazydocker, bottom, mosh|off|
media-pack|Media pack - mpv, cmus, chafa|off|
mail-pack|Mail pack - aerc, notmuch|off|
writing-pack|Writing pack - helix, glow, mdcat|off|
file-pack|File pack - yazi, broot, ranger|off|
EOF
}

profile_install_optional_item() {
    case "$1" in
        ops-pack) install_packages dnf k9s lazydocker bottom mosh ;;
        media-pack) install_packages dnf mpv cmus chafa ;;
        mail-pack) install_packages dnf aerc notmuch ;;
        writing-pack) install_packages dnf helix glow mdcat ;;
        file-pack) install_packages dnf yazi broot ranger ;;
        *) return 1 ;;
    esac
}

profile_install_shell() {
    case "$1" in
        fish) install_packages dnf fish ;;
        bash|"") ;;
        *) return 1 ;;
    esac
}

profile_configure_system() {
    if [[ "${CONFIGURE_SYSTEM:-1}" != "1" ]]; then
        return
    fi

    if have systemctl; then
        sudo systemctl enable --now tlp >/dev/null 2>&1 || true
        sudo systemctl set-default multi-user.target >/dev/null 2>&1 || true
        sudo systemctl --user restart pipewire pipewire-pulse wireplumber >/dev/null 2>&1 || true
    fi

    sudo usermod -aG video "$AUTOLOGIN_USER" >/dev/null 2>&1 || true
    sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
    sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf >/dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${AUTOLOGIN_USER} --noclear %I \$TERM
EOF
    sudo systemctl daemon-reload >/dev/null 2>&1 || true

    sudo tee /etc/sysctl.d/99-quiet-console.conf >/dev/null <<'EOF'
kernel.printk = 3 4 1 3
EOF

    sudo tee /etc/vconsole.conf >/dev/null <<EOF
FONT=${CONSOLE_FONT}
EOF

    sudo sysctl --system >/dev/null 2>&1 || true
}

profile_required_commands() {
    printf '%s\n' \
        zellij lazygit nnn nvim btop newsboat neomutt fastfetch \
        wpctl brightnessctl git rg fzf jq tmux
}

profile_verify_extra() {
    verify_system_value "systemd-default" "systemctl get-default"
    verify_system_value "asahi-packages" "rpm -qa | grep -i asahi | head -5"
    verify_system_value "wpctl-status" "wpctl status | head -20"
    verify_system_value "aplay-devices" "aplay -l | head -20"
    verify_system_value "brightness-get" "brightnessctl get"
    verify_system_value "brightness-max" "brightnessctl max"
    verify_system_value "battery-capacity" "cat /sys/class/power_supply/*/capacity | tr '\n' ' '"
}
