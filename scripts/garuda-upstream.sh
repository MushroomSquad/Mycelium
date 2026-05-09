#!/usr/bin/env bash

set -euo pipefail

ACTION="${1:-sync}"
SOURCE_ROOT="${2:-}"

if [[ -z "$SOURCE_ROOT" ]]; then
    SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

INSTALL_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/mycelium"
STATE_ROOT="$INSTALL_ROOT"
THEME="${MYCELIUM_THEME:-garuda-catppuccin-mocha}"
THEME_DIR="${SOURCE_ROOT}/themes/${THEME}"
UPSTREAM_DIR="${STATE_ROOT}/upstream"

# Load core library
# shellcheck disable=SC1090
source "${SOURCE_ROOT}/scripts/lib/core.sh"

load_upstream_conf() {
    local conf="${THEME_DIR}/upstream.conf"
    [[ -f "$conf" ]] || fail "Missing upstream config: $conf"
    # shellcheck disable=SC1090
    source "$conf"
}

do_sync() {
    load_upstream_conf
    ensure_dir "$UPSTREAM_DIR"

    sync_git_reference "$GARUDA_MOKKA_URL" "${UPSTREAM_DIR}/garuda-mokka" || log "Garuda Mokka sync failed"
    sync_git_reference "$GARUDA_COMMON_URL" "${UPSTREAM_DIR}/garuda-common-settings" || log "Garuda common settings sync failed"
    sync_git_reference "$GARUDA_CATPPUCCIN_URL" "${UPSTREAM_DIR}/garuda-website-catppuccin" || log "Garuda Catppuccin website sync failed"
    sync_git_reference "$GARUDA_PKGBUILDS_URL" "${UPSTREAM_DIR}/garuda-pkgbuilds" || log "Garuda PKGBUILDs sync failed"

    log "Upstream references synced to ${UPSTREAM_DIR}"
}

first_existing_candidate() {
    local candidate
    for candidate in "$@"; do
        if [[ -e "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

read_candidate_map() {
    local map_file="${THEME_DIR}/candidate-map.conf"
    [[ -f "$map_file" ]] || fail "Missing candidate map: $map_file"
    grep -v '^#' "$map_file" | grep -v '^$'
}

do_diff() {
    do_sync

    local line tool chezmoi_target candidates_csv
    while IFS= read -r line; do
        tool="${line%%=*}"
        line="${line#*=}"
        chezmoi_target="${line%%|*}"
        candidates_csv="${line#*|}"

        printf '[theme] %s\n' "$tool"
        printf '  chezmoi: home/%s\n' "$chezmoi_target"

        local chezmoi_file="${SOURCE_ROOT}/home/${chezmoi_target}"
        if [[ -e "$chezmoi_file" ]]; then
            printf '  chezmoi-status: present\n'
        else
            printf '  chezmoi-status: missing\n'
        fi

        IFS=',' read -r -a candidates <<< "$candidates_csv"
        for candidate_rel in "${candidates[@]}"; do
            local candidate_abs="${UPSTREAM_DIR}/${candidate_rel}"
            if [[ -e "$candidate_abs" ]]; then
                printf '  upstream: %s\n' "$candidate_rel"
            fi
        done
    done < <(read_candidate_map)
}

do_import() {
    do_sync

    local line tool chezmoi_target candidates_csv
    local chezmoi_home="${SOURCE_ROOT}/home"

    while IFS= read -r line; do
        tool="${line%%=*}"
        line="${line#*=}"
        chezmoi_target="${line%%|*}"
        candidates_csv="${line#*|}"

        IFS=',' read -r -a candidates <<< "$candidates_csv"
        local abs_candidates=()
        for c in "${candidates[@]}"; do
            abs_candidates+=("${UPSTREAM_DIR}/${c}")
        done

        local source_file
        if source_file="$(first_existing_candidate "${abs_candidates[@]}")"; then
            local target="${chezmoi_home}/${chezmoi_target}"
            ensure_dir "$(dirname "$target")"
            backup_file "$target" || true
            cp "$source_file" "$target" 2>/dev/null || {
                printf '[import] %s: unable to write %s\n' "$tool" "$target"
                continue
            }
            printf '[import] %s: %s -> home/%s\n' "$tool" "$(basename "$source_file")" "$chezmoi_target"
        else
            printf '[import] %s: no upstream candidate found\n' "$tool"
        fi
    done < <(read_candidate_map)

    if have chezmoi; then
        log "Applying chezmoi after import"
        chezmoi apply || log "chezmoi apply encountered issues"
    fi
}

do_shell_import() {
    do_sync

    local chezmoi_home="${SOURCE_ROOT}/home"
    local fish_extract_awk="${THEME_DIR}/fish-extract.awk"

    # Fish extraction
    local fish_candidates=(
        "${UPSTREAM_DIR}/garuda-pkgbuilds/garuda-fish-config/config.fish"
        "${UPSTREAM_DIR}/garuda-mokka/etc/skel/.config/fish/config.fish"
        "${UPSTREAM_DIR}/garuda-common-settings/etc/skel/.config/fish/config.fish"
    )

    local fish_candidate
    if fish_candidate="$(first_existing_candidate "${fish_candidates[@]}")"; then
        if [[ -f "$fish_extract_awk" ]]; then
            local extracted
            extracted="$(awk -f "$fish_extract_awk" "$fish_candidate" 2>/dev/null || true)"
            if [[ -n "$extracted" ]]; then
                printf '[shell-import] fish: extracted managed lines from %s\n' "$(basename "$fish_candidate")"
                # Note: fish config is a template, so imported block goes to a separate snippet
                # The user should review and merge into config.fish.tmpl
                local snippet="${chezmoi_home}/dot_config/fish/garuda-import.fish"
                ensure_dir "$(dirname "$snippet")"
                printf '%s\n' "$extracted" > "$snippet"
                printf '[shell-import] fish: wrote to home/dot_config/fish/garuda-import.fish\n'
            else
                printf '[shell-import] fish: no managed lines extracted\n'
            fi
        else
            printf '[shell-import] fish: extract awk script not found\n'
        fi
    else
        printf '[shell-import] fish: no upstream candidate found\n'
    fi

    # Starship
    local starship_candidates=("${UPSTREAM_DIR}/garuda-pkgbuilds/garuda-starship-prompt/starship.toml")
    local starship_candidate
    if starship_candidate="$(first_existing_candidate "${starship_candidates[@]}")"; then
        local target="${chezmoi_home}/dot_config/starship.toml"
        backup_file "$target" || true
        cp "$starship_candidate" "$target" 2>/dev/null || true
        printf '[shell-import] starship: imported from upstream\n'
    else
        printf '[shell-import] starship: no upstream candidate found\n'
    fi

    # Fastfetch
    local fastfetch_candidates=(
        "${UPSTREAM_DIR}/garuda-mokka/etc/skel/.config/fastfetch/config.jsonc"
        "${UPSTREAM_DIR}/garuda-common-settings/etc/skel/.config/fastfetch/config.jsonc"
    )
    local fastfetch_candidate
    if fastfetch_candidate="$(first_existing_candidate "${fastfetch_candidates[@]}")"; then
        local target="${chezmoi_home}/dot_config/fastfetch/config.jsonc"
        ensure_dir "$(dirname "$target")"
        backup_file "$target" || true
        cp "$fastfetch_candidate" "$target" 2>/dev/null || true
        printf '[shell-import] fastfetch: imported from upstream\n'
    else
        printf '[shell-import] fastfetch: no upstream candidate found\n'
    fi

    if have chezmoi; then
        log "Applying chezmoi after shell-import"
        chezmoi apply || log "chezmoi apply encountered issues"
    fi
}

case "$ACTION" in
    sync)
        do_sync
        ;;
    diff)
        do_diff
        ;;
    import)
        do_import
        ;;
    shell-import)
        do_shell_import
        ;;
    *)
        fail "garuda-upstream.sh: unsupported action: $ACTION"
        ;;
esac
