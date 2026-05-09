function normalize_alias(line, alias_name, alias_value) {
    if (match(line, /^alias[[:space:]]+[^[:space:]]+[[:space:]]+/, m)) {
        alias_name = substr(line, RSTART + 6, RLENGTH - 7)
        alias_value = substr(line, RSTART + RLENGTH)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", alias_value)
        gsub(/^'|'$/, "", alias_value)
        gsub(/^"|"$/, "", alias_value)
        return "abbr -a " alias_name " \"" alias_value "\""
    }
    return line
}
/fastfetch/ || /starship/ || /abbr / || /alias / || /zoxide/ || /eza/ || /bat/ || /fish_greeting/ {
    if ($0 ~ /^alias /) {
        print normalize_alias($0)
    } else {
        print
    }
}
