#!/bin/bash

set -euo pipefail

flags_file="${XDG_CONFIG_HOME:-$HOME/.config}/code-flags.conf"

CODEMAPFILE=()
if [[ -f "${flags_file}" ]]; then
    mapfile -t < "${flags_file}" CODEMAPFILE
fi

codeflags=()
for line in "${CODEMAPFILE[@]}"; do
    if [[ ! "${line}" =~ ^[[:space:]]*#.* ]] && [[ -n "${line}" ]]; then
        codeflags+=("${line}")
    fi
done

# don't edit the electron binary name here! simply change the variable in the PKGBUILD and we will sed it into the correct one :)
name=electron
flags_file="${XDG_CONFIG_HOME:-$HOME/.config}/${name}-flags.conf"
fallback_file="${XDG_CONFIG_HOME:-$HOME/.config}/electron-flags.conf"

lines=()
if [[ -f "${flags_file}" ]]; then
    mapfile -t lines < "${flags_file}"
elif [[ -f "${fallback_file}" ]]; then
    mapfile -t lines < "${fallback_file}"
fi

electronflags=()
for line in "${lines[@]}"; do
    if [[ ! "${line}" =~ ^[[:space:]]*#.* ]] && [[ -n "${line}" ]]; then
        electronflags+=("${line}")
    fi
done

for arg in "$@"; do
    if [[ "$arg" == "--file-write" ]] || [[ "$arg" == "--file-chmod" ]]; then
        ELECTRON_RUN_AS_NODE=1 exec /usr/lib/${name}/electron /opt/visual-studio-code/resources/app/out/cli.js "${electronflags[@]}" "${codeflags[@]}" "$@"
    fi
done

ELECTRON_RUN_AS_NODE=1 exec /usr/lib/${name}/electron /opt/visual-studio-code/resources/app/out/cli.js "${electronflags[@]}" /opt/visual-studio-code/resources/app/code.mjs "${codeflags[@]}" "$@"
