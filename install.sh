#!/usr/bin/env bash

set -euo pipefail

APP_NAME="Mycelium"
APP_ID="mycelium"
INSTALL_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/${APP_ID}"
REPO_DIR="${INSTALL_ROOT}/repo"
REPO_URL_DEFAULT="${MYCELIUM_REPO_URL_DEFAULT:-https://github.com/MushroomSquad/Mycelium.git}"
ACTION="${1:-install}"
SCRIPT_DIR=""

if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

log() {
    printf '[%s] %s\n' "$APP_ID" "$*"
}

fail() {
    printf '[%s] error: %s\n' "$APP_ID" "$*" >&2
    exit 1
}

have() {
    command -v "$1" >/dev/null 2>&1
}

ensure_bootstrap_tools() {
    local missing=()
    have git || missing+=("git")
    have curl || missing+=("curl")
    if [[ ${#missing[@]} -eq 0 ]]; then
        return
    fi

    log "Missing bootstrap tools: ${missing[*]}"

    if have brew; then
        brew install "${missing[@]}"
        return
    fi
    if have apt-get; then
        sudo apt-get update
        sudo apt-get install -y "${missing[@]}"
        return
    fi
    if have dnf; then
        sudo dnf install -y "${missing[@]}"
        return
    fi
    if have pacman; then
        sudo pacman -Sy --noconfirm "${missing[@]}"
        return
    fi
    if have zypper; then
        sudo zypper --non-interactive install "${missing[@]}"
        return
    fi

    fail "Unable to install bootstrap dependencies automatically. Install git first."
}

resolve_repo_url() {
    if [[ -n "${MYCELIUM_REPO_URL:-}" ]]; then
        printf '%s\n' "$MYCELIUM_REPO_URL"
        return
    fi
    if [[ -n "${MYCELIUM_REPO_SLUG:-}" ]]; then
        printf 'https://github.com/%s.git\n' "$MYCELIUM_REPO_SLUG"
        return
    fi
    if [[ -n "$REPO_URL_DEFAULT" ]]; then
        printf '%s\n' "$REPO_URL_DEFAULT"
        return
    fi
    if [[ -d "$REPO_DIR/.git" ]]; then
        git -C "$REPO_DIR" remote get-url origin
        return
    fi

    fail "Set MYCELIUM_REPO_SLUG or MYCELIUM_REPO_URL for remote bootstrap, or run install.sh from a local checkout."
}

run_local_install() {
    local repo_root="$1"
    "${repo_root}/scripts/mycelium.sh" "$ACTION" "$repo_root"
}

bootstrap_repo() {
    local repo_url="$1"

    ensure_bootstrap_tools
    mkdir -p "$INSTALL_ROOT"

    if [[ -d "$REPO_DIR/.git" ]]; then
        log "Updating source repo in $REPO_DIR"
        git -C "$REPO_DIR" fetch --tags --prune origin
        git -C "$REPO_DIR" pull --ff-only origin "$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD)"
    else
        log "Cloning source repo into $REPO_DIR"
        git clone "$repo_url" "$REPO_DIR"
    fi
}

main() {
    if [[ -x "${SCRIPT_DIR}/scripts/mycelium.sh" ]]; then
        run_local_install "$SCRIPT_DIR"
        return
    fi

    local repo_url
    repo_url="$(resolve_repo_url)"
    bootstrap_repo "$repo_url"
    run_local_install "$REPO_DIR"
}

main "$@"
