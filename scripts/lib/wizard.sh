TUI_MODE="${MYCELIUM_TUI:-1}"
SELECTED_OPTIONAL_IDS=()

tty_available() {
    [[ -r /dev/tty && -w /dev/tty ]]
}

prompt_backend() {
    if [[ "$TUI_MODE" != "1" ]]; then
        return
    fi
    if ! tty_available; then
        return
    fi
    if have whiptail; then
        printf 'whiptail\n'
        return
    fi
    if have dialog; then
        printf 'dialog\n'
        return
    fi
    printf 'text\n'
}

prompt_yes_no() {
    local title="$1"
    local prompt="$2"
    local default="${3:-yes}"
    local backend reply

    backend="$(prompt_backend)"
    case "$backend" in
        whiptail)
            if [[ "$default" == "yes" ]]; then
                whiptail --title "$title" --yesno "$prompt" 12 72
            else
                whiptail --defaultno --title "$title" --yesno "$prompt" 12 72
            fi
            ;;
        dialog)
            if [[ "$default" == "yes" ]]; then
                dialog --stdout --title "$title" --yesno "$prompt" 12 72
            else
                dialog --stdout --defaultno --title "$title" --yesno "$prompt" 12 72
            fi
            ;;
        text)
            printf '%s [y/N]: ' "$prompt" > /dev/tty
            read -r reply < /dev/tty || true
            if [[ -z "$reply" ]]; then
                [[ "$default" == "yes" ]]
            else
                [[ "$reply" =~ ^[Yy]$ ]]
            fi
            ;;
        *)
            [[ "$default" == "yes" ]]
            ;;
    esac
}

select_optional_packages_text() {
    local -n ids_ref=$1
    local -n labels_ref=$2
    local response idx item

    if [[ ${#ids_ref[@]} -eq 0 ]]; then
        return
    fi

    printf '\nOptional packages for profile %s:\n' "$PROFILE" > /dev/tty
    for idx in "${!ids_ref[@]}"; do
        printf '  %d. %s\n' "$((idx + 1))" "${labels_ref[$idx]}" > /dev/tty
    done
    printf 'Enter comma-separated numbers to install, or leave blank for none: ' > /dev/tty
    read -r response < /dev/tty || true

    [[ -z "$response" ]] && return

    response="${response// /}"
    IFS=',' read -r -a item <<< "$response"
    for idx in "${item[@]}"; do
        if [[ "$idx" =~ ^[0-9]+$ ]] && (( idx >= 1 && idx <= ${#ids_ref[@]} )); then
            SELECTED_OPTIONAL_IDS+=("${ids_ref[$((idx - 1))]}")
        fi
    done
}

select_optional_packages() {
    local backend catalog line id label default enabled check_cmd result cleaned token
    local -a ids labels defaults args

    if [[ -n "${MYCELIUM_OPTIONAL:-}" ]]; then
        IFS=',' read -r -a SELECTED_OPTIONAL_IDS <<< "$MYCELIUM_OPTIONAL"
        return
    fi

    if [[ "$TUI_MODE" != "1" ]]; then
        return
    fi

    mapfile -t catalog < <(profile_optional_catalog)
    [[ ${#catalog[@]} -eq 0 ]] && return

    ids=()
    labels=()
    defaults=()
    for line in "${catalog[@]}"; do
        IFS='|' read -r id label default check_cmd <<< "$line"
        ids+=("$id")
        labels+=("$label")
        defaults+=("$default")
    done

    backend="$(prompt_backend)"
    case "$backend" in
        whiptail)
            args=()
            for line in "${catalog[@]}"; do
                IFS='|' read -r id label default check_cmd <<< "$line"
                enabled="OFF"
                [[ "$default" == "on" ]] && enabled="ON"
                args+=("$id" "$label" "$enabled")
            done
            result="$(whiptail --title "Mycelium Optional Packages" --checklist "Select optional packages for ${PROFILE}" 24 90 14 "${args[@]}" < /dev/tty 3>&1 1>&2 2>&3)" || true
            cleaned="${result//\"/}"
            for token in $cleaned; do
                SELECTED_OPTIONAL_IDS+=("$token")
            done
            ;;
        dialog)
            args=()
            for line in "${catalog[@]}"; do
                IFS='|' read -r id label default check_cmd <<< "$line"
                enabled="off"
                [[ "$default" == "on" ]] && enabled="on"
                args+=("$id" "$label" "$enabled")
            done
            result="$(dialog --stdout --checklist "Select optional packages for ${PROFILE}" 24 90 14 "${args[@]}" < /dev/tty)" || true
            cleaned="${result//\"/}"
            for token in $cleaned; do
                SELECTED_OPTIONAL_IDS+=("$token")
            done
            ;;
        text)
            select_optional_packages_text ids labels
            ;;
        *)
            ;;
    esac
}
