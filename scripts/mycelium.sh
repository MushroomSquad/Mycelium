#!/usr/bin/env bash

set -euo pipefail

ACTION="${1:-install}"
SOURCE_ROOT="${2:-}"

if [[ -z "$SOURCE_ROOT" ]]; then
    SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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
        exec zellij --layout "$AUTOSTART_LAYOUT" --session "$AUTOSTART_SESSION"
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
    profile)
        show_profile
        ;;
    *)
        fail "Unsupported action: $ACTION"
        ;;
esac
