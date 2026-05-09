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

ensure_curl() {
    have curl && return
    have wget && return

    local missing=(curl)
    log "Missing bootstrap tool: curl"

    if have brew; then brew install "${missing[@]}"; return; fi
    if have apt-get; then sudo apt-get update && sudo apt-get install -y "${missing[@]}"; return; fi
    if have dnf; then sudo dnf install -y "${missing[@]}"; return; fi
    if have pacman; then sudo pacman -Sy --noconfirm "${missing[@]}"; return; fi
    if have zypper; then sudo zypper --non-interactive install "${missing[@]}"; return; fi

    fail "curl or wget is required for installation."
}

ensure_git() {
    have git && return

    local missing=(git)
    log "Missing bootstrap tool: git"

    if have brew; then brew install "${missing[@]}"; return; fi
    if have apt-get; then sudo apt-get update && sudo apt-get install -y "${missing[@]}"; return; fi
    if have dnf; then sudo dnf install -y "${missing[@]}"; return; fi
    if have pacman; then sudo pacman -Sy --noconfirm "${missing[@]}"; return; fi
    if have zypper; then sudo zypper --non-interactive install "${missing[@]}"; return; fi

    fail "Unable to install git automatically. Install git first."
}

fetch() {
    local url="$1" target="$2"
    if have curl; then
        curl -fsSL "$url" -o "$target"
    elif have wget; then
        wget -qO "$target" "$url"
    else
        fail "Neither curl nor wget available"
    fi
}

resolve_github_slug() {
    if [[ -n "${MYCELIUM_REPO_SLUG:-}" ]]; then
        printf '%s\n' "$MYCELIUM_REPO_SLUG"
        return
    fi
    # Extract owner/repo from default URL
    local url="$REPO_URL_DEFAULT"
    url="${url%.git}"
    url="${url#https://github.com/}"
    if [[ "$url" == */* ]]; then
        printf '%s\n' "$url"
        return
    fi
    return 1
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

bootstrap_tarball() {
    local slug="$1"
    local branch="${MYCELIUM_BRANCH:-main}"
    local tarball_url="https://github.com/${slug}/archive/refs/heads/${branch}.tar.gz"
    local tmp_tar

    ensure_curl
    mkdir -p "$INSTALL_ROOT"

    tmp_tar="$(mktemp)"
    log "Downloading ${slug}@${branch} via tarball"
    fetch "$tarball_url" "$tmp_tar"

    rm -rf "$REPO_DIR"
    mkdir -p "$REPO_DIR"
    tar xzf "$tmp_tar" --strip-components=1 -C "$REPO_DIR"
    rm -f "$tmp_tar"

    log "Extracted to $REPO_DIR"
}

bootstrap_git() {
    local repo_url="$1"

    ensure_git
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

bootstrap_remote() {
    # Prefer tarball (no git needed), fall back to git clone
    local slug
    if slug="$(resolve_github_slug)"; then
        bootstrap_tarball "$slug"
    else
        local repo_url
        repo_url="$(resolve_repo_url)"
        bootstrap_git "$repo_url"
    fi
}

main() {
    # Local checkout — run directly
    if [[ -n "$SCRIPT_DIR" ]] && [[ -x "${SCRIPT_DIR}/scripts/mycelium.sh" ]]; then
        run_local_install "$SCRIPT_DIR"
        return
    fi

    # Already installed — update via git if available
    if [[ -d "$REPO_DIR/.git" ]] && have git; then
        bootstrap_git "$(resolve_repo_url)"
        run_local_install "$REPO_DIR"
        return
    fi

    # Remote bootstrap
    bootstrap_remote
    run_local_install "$REPO_DIR"
}

main "$@"
