#!/bin/bash

flags_file="${XDG_CONFIG_HOME:-$HOME/.config}/code-flags.conf"

lines=()
if [[ -f "${flags_file}" ]]; then
    mapfile -t lines < "${flags_file}"
fi

codeflags=()
for line in "${lines[@]}"; do
    if [[ ! "${line}" =~ ^[[:space:]]*#.* ]] && [[ -n "${line}" ]]; then
        codeflags+=("${line}")
    fi
done

exec /opt/visual-studio-code/bin/code "${codeflags[@]}" "$@"
