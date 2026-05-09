OS="$(uname -s)"
ARCH="$(uname -m)"
OS_ID=""
OS_ID_LIKE=""
OS_NAME=""

load_os_release() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        OS_ID="${ID:-}"
        OS_ID_LIKE="${ID_LIKE:-}"
        OS_NAME="${PRETTY_NAME:-${NAME:-}}"
    else
        OS_NAME="$OS"
    fi
}

string_contains() {
    local haystack="$1"
    local needle="$2"
    [[ " ${haystack} " == *" ${needle} "* ]]
}

detect_package_manager() {
    if have dnf; then
        printf 'dnf\n'
    elif have apt-get; then
        printf 'apt\n'
    elif have pacman; then
        printf 'pacman\n'
    elif have zypper; then
        printf 'zypper\n'
    elif have brew; then
        printf 'brew\n'
    else
        printf 'unknown\n'
    fi
}

detect_profile() {
    if [[ -n "${MYCELIUM_PROFILE:-}" ]]; then
        PROFILE="$MYCELIUM_PROFILE"
        return
    fi

    load_os_release

    if [[ "$OS" == "Darwin" ]]; then
        PROFILE="macos-generic"
        return
    fi

    if [[ "$OS" == "Linux" ]]; then
        if [[ "$OS_ID" == "fedora" ]] && [[ "$ARCH" == "aarch64" ]]; then
            if rpm -qa 2>/dev/null | grep -qi asahi; then
                PROFILE="fedora-asahi"
                return
            fi
        fi
        if [[ "$OS_ID" == "fedora" ]]; then
            PROFILE="fedora-generic"
            return
        fi
        if string_contains "$OS_ID_LIKE" "arch" || [[ "$OS_ID" == "arch" || "$OS_ID" == "cachyos" ]]; then
            PROFILE="arch-generic"
            return
        fi
        if string_contains "$OS_ID_LIKE" "debian" || [[ "$OS_ID" == "debian" || "$OS_ID" == "ubuntu" ]]; then
            PROFILE="debian-generic"
            return
        fi
        if string_contains "$OS_ID_LIKE" "suse" || [[ "$OS_ID" == suse* || "$OS_ID" == opensuse* ]]; then
            PROFILE="suse-generic"
            return
        fi
        PROFILE="linux-generic"
        return
    fi

    PROFILE="unknown"
}

load_profile_impl() {
    local profile_sh="${SOURCE_ROOT}/profiles/${PROFILE}.sh"
    local profile_conf="${SOURCE_ROOT}/profiles/${PROFILE}.conf"

    if [[ -f "$profile_sh" ]]; then
        # shellcheck disable=SC1090
        source "$profile_sh"
    elif [[ -f "$profile_conf" ]]; then
        # shellcheck disable=SC1090
        source "${SOURCE_ROOT}/profiles/_engine.sh"
        engine_load_profile "$profile_conf"
    else
        fail "Missing profile: $PROFILE (no .sh or .conf found)"
    fi
}
