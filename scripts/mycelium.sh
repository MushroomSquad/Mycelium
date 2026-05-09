#!/usr/bin/env bash

set -euo pipefail

ACTION="${1:-install}"
SOURCE_ROOT="${2:-}"

if [[ -z "$SOURCE_ROOT" ]]; then
    _self="${BASH_SOURCE[0]}"
    # Resolve symlinks (e.g. ~/.local/bin/mycelium -> repo/scripts/mycelium.sh)
    while [[ -L "$_self" ]]; do
        _dir="$(cd "$(dirname "$_self")" && pwd)"
        _self="$(readlink "$_self")"
        [[ "$_self" != /* ]] && _self="${_dir}/${_self}"
    done
    SOURCE_ROOT="$(cd "$(dirname "$_self")/.." && pwd)"
    unset _self _dir
fi

# Load core libraries
# shellcheck disable=SC1090
source "${SOURCE_ROOT}/scripts/lib/core.sh"
# shellcheck disable=SC1090
source "${SOURCE_ROOT}/scripts/lib/detect.sh"

SCRIPTS_DIR="${SOURCE_ROOT}/scripts"
AUTOSTART_LAYOUT="${MYCELIUM_LAYOUT_NAME:-cockpit}"
AUTOSTART_SESSION="${MYCELIUM_SESSION_NAME:-cockpit}"

show_profile() {
    detect_profile
    local primary_shell="${MYCELIUM_PRIMARY_SHELL:-}"
    if [[ -z "$primary_shell" ]]; then
        if [[ "$PROFILE" == "fedora-asahi" ]]; then
            primary_shell="fish"
        else
            primary_shell="bash"
        fi
    fi
    printf 'profile=%s\n' "$PROFILE"
    printf 'os=%s\n' "${OS_NAME:-$OS}"
    printf 'arch=%s\n' "$ARCH"
    printf 'package_manager=%s\n' "$(detect_package_manager)"
    printf 'primary_shell=%s\n' "$primary_shell"
}

case "$ACTION" in
    install)
        "${SCRIPTS_DIR}/provision.sh" install "$SOURCE_ROOT"
        ;;
    update)
        "${SCRIPTS_DIR}/provision.sh" update "$SOURCE_ROOT"
        ;;
    start)
        exec zellij -l "$AUTOSTART_LAYOUT"
        ;;
    verify)
        "${SCRIPTS_DIR}/provision.sh" verify "$SOURCE_ROOT"
        ;;
    theme-sync)
        "${SCRIPTS_DIR}/garuda-upstream.sh" sync "$SOURCE_ROOT"
        ;;
    theme-diff)
        "${SCRIPTS_DIR}/garuda-upstream.sh" diff "$SOURCE_ROOT"
        ;;
    theme-import)
        "${SCRIPTS_DIR}/garuda-upstream.sh" import "$SOURCE_ROOT"
        ;;
    garuda-shell-import)
        "${SCRIPTS_DIR}/garuda-upstream.sh" shell-import "$SOURCE_ROOT"
        ;;
    restart)
        if have zellij; then
            local current_session
            current_session="${ZELLIJ_SESSION_NAME:-}"
            if [[ -n "$current_session" ]]; then
                log "Restarting zellij session: $current_session"
                zellij kill-session "$current_session" 2>/dev/null || true
                sleep 0.3
            fi
            exec zellij -l "$AUTOSTART_LAYOUT"
        else
            fail "zellij is not installed"
        fi
        ;;
    restart-all)
        if have zellij; then
            log "Killing all zellij sessions"
            zellij kill-all-sessions 2>/dev/null || true
            sleep 0.3
            exec zellij -l "$AUTOSTART_LAYOUT"
        else
            fail "zellij is not installed"
        fi
        ;;
    profile)
        show_profile
        ;;
    *)
        fail "Unsupported action: $ACTION. Available: install update start restart restart-all verify profile theme-sync theme-diff theme-import garuda-shell-import"
        ;;
esac
