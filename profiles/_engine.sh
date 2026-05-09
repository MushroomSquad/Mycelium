# Profile engine: loads .conf and generates profile_* functions
# For .sh profiles (fedora-asahi), source directly instead.

_engine_load_conf() {
    local conf_file="$1"
    [[ -f "$conf_file" ]] || fail "Missing profile conf: $conf_file"

    PROFILE_PKG_MANAGER=""
    PROFILE_REQUIRED=""
    PROFILE_VERIFY_COMMANDS=""
    PROFILE_CONFIGURE_SYSTEM="0"
    PROFILE_VERIFY_EXTRA=""

    # shellcheck disable=SC1090
    source "$conf_file"

    if [[ "$PROFILE_PKG_MANAGER" == "auto" ]]; then
        PROFILE_PKG_MANAGER="$(detect_package_manager)"
    fi
}

_engine_collect_opt_ids() {
    local var
    for var in $(compgen -v PROFILE_OPT_ 2>/dev/null || set | grep -oE '^PROFILE_OPT_[a-z_]+_label' | sed 's/_label$//'); do
        var="${var#PROFILE_OPT_}"
        var="${var%_label}"
        [[ -n "$var" ]] && printf '%s\n' "$var"
    done | sort -u
}

_engine_generate_functions() {
    profile_install_required() {
        if [[ -z "$PROFILE_REQUIRED" ]]; then
            [[ "$PROFILE_PKG_MANAGER" == "unknown" ]] && return 0
            fail "No install recipe for profile: ${PROFILE}"
        fi
        # shellcheck disable=SC2086
        install_packages "$PROFILE_PKG_MANAGER" $PROFILE_REQUIRED
    }

    profile_optional_catalog() {
        local id label_var label
        for id in $(_engine_collect_opt_ids); do
            label_var="PROFILE_OPT_${id}_label"
            label="${!label_var:-}"
            [[ -n "$label" ]] && printf '%s|%s|off|\n' "$id" "$label"
        done
    }

    profile_install_optional_item() {
        local id="$1"
        local pkgs_var="PROFILE_OPT_${id}_pkgs"
        local pkgs="${!pkgs_var:-}"
        [[ -z "$pkgs" ]] && return 1
        # shellcheck disable=SC2086
        install_packages "$PROFILE_PKG_MANAGER" $pkgs
    }

    profile_install_shell() {
        local shell_var="PROFILE_SHELL_${1}"
        local pkg="${!shell_var:-}"
        case "$1" in
            bash|"") return 0 ;;
        esac
        [[ -z "$pkg" ]] && return 1
        install_packages "$PROFILE_PKG_MANAGER" "$pkg"
    }

    profile_configure_system() {
        :
    }

    profile_required_commands() {
        local cmd
        for cmd in $PROFILE_VERIFY_COMMANDS; do
            printf '%s\n' "$cmd"
        done
    }

    profile_verify_extra() {
        local entry label cmd
        [[ -z "$PROFILE_VERIFY_EXTRA" ]] && return 0
        IFS=',' read -r -a entries <<< "$PROFILE_VERIFY_EXTRA"
        for entry in "${entries[@]}"; do
            label="${entry%%:*}"
            cmd="${entry#*:}"
            [[ -n "$label" && -n "$cmd" ]] && verify_system_value "$label" "$cmd"
        done
    }
}

engine_load_profile() {
    local conf_file="$1"
    _engine_load_conf "$conf_file"
    _engine_generate_functions
}
