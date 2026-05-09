#!/usr/bin/env bash

set -euo pipefail

ACTION="${1:-install}"
SOURCE_ROOT="${2:-}"

if [[ -z "$SOURCE_ROOT" ]]; then
    SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

INSTALL_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/mycelium"
STATE_ROOT="$INSTALL_ROOT"
TARGET_REPO_DIR="${INSTALL_ROOT}/repo"
TARGET_BIN_DIR="${HOME}/.local/bin"
TARGET_BIN="${TARGET_BIN_DIR}/mycelium"
CONFIGURE_SYSTEM="${MYCELIUM_CONFIGURE_SYSTEM:-}"
AUTOLOGIN_USER="${MYCELIUM_AUTOLOGIN_USER:-$USER}"
CONSOLE_FONT="${MYCELIUM_CONSOLE_FONT:-ter-v32n}"
PRIMARY_SHELL="${MYCELIUM_PRIMARY_SHELL:-}"
PROFILE=""

# Load libraries
for lib in "${SOURCE_ROOT}/scripts/lib/"*.sh; do
    # shellcheck disable=SC1090
    source "$lib"
done

resolve_system_config_default() {
    if [[ -n "$CONFIGURE_SYSTEM" ]]; then
        return
    fi
    if [[ "$PROFILE" == "fedora-asahi" ]]; then
        # Default to enabled on fedora-asahi; prompt only if tty available
        CONFIGURE_SYSTEM="1"
        if [[ -t 0 && -t 1 ]]; then
            if ! prompt_yes_no "Mycelium System Setup" "Apply tty1 autologin, multi-user.target, quiet console and console font settings for ${PROFILE}?" "yes"; then
                CONFIGURE_SYSTEM="0"
            fi
        else
            log "Non-interactive mode: applying system config for ${PROFILE}"
        fi
    else
        CONFIGURE_SYSTEM="0"
    fi
}

resolve_primary_shell_default() {
    if [[ -n "$PRIMARY_SHELL" ]]; then
        return
    fi
    if [[ "$PROFILE" == "fedora-asahi" ]]; then
        PRIMARY_SHELL="fish"
    else
        PRIMARY_SHELL="bash"
    fi
}

run_install_wizard() {
    SELECTED_OPTIONAL_IDS=()
    resolve_system_config_default
    resolve_primary_shell_default
    select_optional_packages
    if [[ -z "${MYCELIUM_PRIMARY_SHELL:-}" ]] && [[ "$TUI_MODE" == "1" ]] && [[ "$PROFILE" != "fedora-asahi" ]]; then
        if prompt_yes_no "Mycelium Shell" "Use fish as the primary interactive shell for Mycelium?" "no"; then
            PRIMARY_SHELL="fish"
        fi
    fi
}

install_optional_packages() {
    local id
    for id in "${SELECTED_OPTIONAL_IDS[@]}"; do
        log "Installing optional package set: $id"
        profile_install_optional_item "$id" || log "Optional package failed: $id"
    done
}

sync_repo() {
    ensure_dir "$INSTALL_ROOT"
    if [[ "$SOURCE_ROOT" != "$TARGET_REPO_DIR" ]]; then
        if [[ -d "$TARGET_REPO_DIR/.git" ]]; then
            log "Updating installed repo"
            git -C "$TARGET_REPO_DIR" fetch --tags --prune origin
            git -C "$TARGET_REPO_DIR" pull --ff-only origin "$(git -C "$TARGET_REPO_DIR" rev-parse --abbrev-ref HEAD)"
        else
            log "Installing repo into $TARGET_REPO_DIR"
            rm -rf "$TARGET_REPO_DIR"
            git clone "$SOURCE_ROOT" "$TARGET_REPO_DIR" >/dev/null 2>&1 || {
                mkdir -p "$TARGET_REPO_DIR"
                cp -R "$SOURCE_ROOT"/. "$TARGET_REPO_DIR"/
            }
        fi
    fi
}

link_command() {
    ensure_dir "$TARGET_BIN_DIR"
    ln -sfn "${TARGET_REPO_DIR}/scripts/mycelium.sh" "$TARGET_BIN"
}

write_metadata() {
    ensure_state_root
    {
        printf 'PROFILE=%q\n' "$PROFILE"
        printf 'PRIMARY_SHELL=%q\n' "$PRIMARY_SHELL"
        printf 'OS=%q\n' "$OS"
        printf 'ARCH=%q\n' "$ARCH"
        printf 'OS_NAME=%q\n' "${OS_NAME:-$OS}"
        printf 'CONFIGURE_SYSTEM=%q\n' "${CONFIGURE_SYSTEM:-0}"
        printf 'OPTIONAL_SELECTED=%q\n' "$(IFS=,; printf '%s' "${SELECTED_OPTIONAL_IDS[*]}")"
    } > "${STATE_ROOT}/install.env"
}

migrate_from_v1() {
    local marker_file="${STATE_ROOT}/.v2-migrated"
    [[ -f "$marker_file" ]] && return 0

    local file markers
    markers=("Mycelium" "Mycelium UX" "Mycelium Theme" "Garuda Shell" "Garuda Fish Init" "Garuda Fish Abbr" "Garuda Fish Import")

    for file in "${HOME}/.bashrc" "${HOME}/.bash_profile" "${HOME}/.zshrc" "${HOME}/.zprofile" "${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish"; do
        [[ -f "$file" ]] || continue
        for marker in "${markers[@]}"; do
            if grep -q "# >>> ${marker} >>>" "$file" 2>/dev/null; then
                awk -v marker="$marker" '
                    BEGIN { skip = 0 }
                    $0 == "# >>> " marker " >>>" { skip = 1; next }
                    $0 == "# <<< " marker " <<<" { skip = 0; next }
                    skip == 0 { print }
                ' "$file" > "${file}.tmp" 2>/dev/null && mv "${file}.tmp" "$file" || true
            fi
        done
    done

    ensure_state_root
    touch "$marker_file"
    log "Migrated from v1 managed blocks"
}

apply_chezmoi() {
    ensure_chezmoi

    local mycelium_home="${TARGET_REPO_DIR}/home"
    [[ -d "$mycelium_home" ]] || mycelium_home="${SOURCE_ROOT}/home"

    # Sync source files into chezmoi's persistent source directory
    local chezmoi_source
    chezmoi_source="$(chezmoi source-path 2>/dev/null || echo "${HOME}/.local/share/chezmoi")"
    mkdir -p "$chezmoi_source"
    cp -R "${mycelium_home}/." "${chezmoi_source}/"
    log "Synced chezmoi source to ${chezmoi_source}"

    # Init config (processes .chezmoi.toml.tmpl) and apply all managed files
    MYCELIUM_PROFILE="$PROFILE" \
    MYCELIUM_PRIMARY_SHELL="$PRIMARY_SHELL" \
    MYCELIUM_LAYOUT_NAME="${MYCELIUM_LAYOUT_NAME:-cockpit}" \
    MYCELIUM_SESSION_NAME="${MYCELIUM_SESSION_NAME:-cockpit}" \
        chezmoi init --apply
}

kill_existing_sessions() {
    if have zellij; then
        zellij kill-all-sessions >/dev/null 2>&1 || true
    fi
}

print_next_steps() {
    printf '\n'
    printf 'Profile: %s\n' "$PROFILE"
    printf 'Primary shell: %s\n' "$PRIMARY_SHELL"
    printf 'Start: zellij --layout cockpit --session cockpit\n'
    printf 'Update: mycelium update\n'
    printf 'Verify: mycelium verify\n'
    printf 'Profile: mycelium profile\n'
}

install_cargo_fallbacks() {
    # Tools that may not be in distro repos
    local -A cargo_tools=(
        [starship]="starship"
        [zoxide]="zoxide"
        [eza]="eza"
        [bat]="bat"
    )

    local name pkg needs_cargo=0
    for name in "${!cargo_tools[@]}"; do
        if ! have "$name"; then
            needs_cargo=1
            break
        fi
    done

    [[ "$needs_cargo" -eq 0 ]] && return 0

    if ! have cargo; then
        if have rustup; then
            rustup default stable
        else
            log "Installing Rust via rustup"
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
            refresh_path
        fi
    fi

    have cargo || { log "cargo not available, skipping fallback installs"; return 0; }

    for name in "${!cargo_tools[@]}"; do
        if ! have "$name"; then
            pkg="${cargo_tools[$name]}"
            log "Installing $name via cargo (not in repos)"
            cargo install --locked "$pkg" 2>/dev/null || cargo install "$pkg" || log "cargo install $pkg failed"
            refresh_path
        fi
    done
}

set_login_shell() {
    local target_shell="$1"
    [[ "$target_shell" == "bash" ]] && return 0

    local shell_path
    shell_path="$(command -v "$target_shell" 2>/dev/null || true)"
    [[ -z "$shell_path" ]] && return 0

    local current_shell
    current_shell="$(getent passwd "$USER" 2>/dev/null | cut -d: -f7 || true)"

    if [[ "$current_shell" != "$shell_path" ]]; then
        log "Setting login shell to $shell_path"
        sudo chsh -s "$shell_path" "$USER" 2>/dev/null || chsh -s "$shell_path" 2>/dev/null || log "Unable to change login shell (run: chsh -s $shell_path)"
    fi
}

do_install() {
    refresh_path
    detect_profile
    log "Detected profile: $PROFILE"
    load_profile_impl
    run_install_wizard
    profile_install_required
    install_cargo_fallbacks
    profile_install_shell "$PRIMARY_SHELL"
    install_optional_packages
    profile_configure_system
    set_login_shell "$PRIMARY_SHELL"
    sync_repo
    link_command
    write_metadata
    migrate_from_v1
    apply_chezmoi
    kill_existing_sessions
    print_next_steps
}

do_update() {
    sync_repo
    SOURCE_ROOT="$TARGET_REPO_DIR"
    # Reload libraries from updated repo
    for lib in "${SOURCE_ROOT}/scripts/lib/"*.sh; do
        # shellcheck disable=SC1090
        source "$lib"
    done
    do_install
}

run_verify() {
    local cmd
    refresh_path
    detect_profile
    load_profile_impl
    ensure_state_root
    : > "${STATE_ROOT}/verify.tsv"

    append_verify_result "profile" "info" "$PROFILE"
    append_verify_result "os" "info" "${OS_NAME:-$OS} (${ARCH})"

    while IFS= read -r cmd; do
        [[ -n "$cmd" ]] && verify_command "$cmd"
    done < <(profile_required_commands)

    verify_command "chezmoi"
    verify_file "binary" "$TARGET_BIN"
    profile_verify_extra

    # chezmoi managed files check
    if have chezmoi; then
        if chezmoi verify >/dev/null 2>&1; then
            append_verify_result "chezmoi-state" "ok" "all managed files in sync"
        else
            append_verify_result "chezmoi-state" "warn" "drift detected (run: chezmoi diff)"
        fi
    fi

    awk -F '\t' '
        BEGIN { printf "%-10s %-20s %s\n", "STATUS", "CHECK", "DETAIL" }
        { printf "%-10s %-20s %s\n", $1, $2, $3 }
    ' "${STATE_ROOT}/verify.tsv"
}

case "$ACTION" in
    install)
        do_install
        ;;
    update)
        do_update
        ;;
    verify)
        run_verify
        ;;
    *)
        fail "provision.sh: unsupported action: $ACTION"
        ;;
esac
