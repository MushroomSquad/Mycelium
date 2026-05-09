APP_NAME="Mycelium"
APP_ID="mycelium"

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

refresh_path() {
    export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
}

ensure_dir() {
    mkdir -p "$1" 2>/dev/null
}

ensure_state_root() {
    if mkdir -p "$STATE_ROOT" 2>/dev/null; then
        return
    fi
    STATE_ROOT="/tmp/${APP_ID}"
    mkdir -p "$STATE_ROOT"
}

backup_file() {
    local path="$1"
    if [[ -f "$path" ]]; then
        cp "$path" "${path}.bak.$(date +%Y%m%d%H%M%S)"
    fi
}

download_file() {
    local url="$1"
    local target="$2"

    ensure_dir "$(dirname "$target")"
    if have curl; then
        curl -fsSL "$url" -o "$target"
        return
    fi
    if have wget; then
        wget -qO "$target" "$url"
        return
    fi
    return 1
}

sync_git_reference() {
    local repo_url="$1"
    local target_dir="$2"

    ensure_dir "$(dirname "$target_dir")"
    if [[ -d "$target_dir/.git" ]]; then
        git -C "$target_dir" fetch --depth=1 origin
        git -C "$target_dir" reset --hard origin/HEAD
    else
        git clone --depth=1 "$repo_url" "$target_dir"
    fi
}

append_verify_result() {
    local label="$1"
    local status="$2"
    local detail="$3"
    printf '%s\t%s\t%s\n' "$status" "$label" "$detail" >> "${STATE_ROOT}/verify.tsv"
}

verify_command() {
    local cmd="$1"
    if have "$cmd"; then
        append_verify_result "$cmd" "ok" "$(command -v "$cmd")"
    else
        append_verify_result "$cmd" "missing" "not found in PATH"
    fi
}

verify_file() {
    local label="$1"
    local path="$2"
    if [[ -e "$path" ]]; then
        append_verify_result "$label" "ok" "$path"
    else
        append_verify_result "$label" "missing" "$path"
    fi
}

verify_system_value() {
    local label="$1"
    local cmd="$2"
    local output
    if output="$(bash -lc "$cmd" 2>/dev/null)" && [[ -n "$output" ]]; then
        append_verify_result "$label" "ok" "$output"
    else
        append_verify_result "$label" "warn" "unavailable"
    fi
}
