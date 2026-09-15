#!/bin/bash

flags_file="${XDG_CONFIG_HOME:-$HOME/.config}/claude-desktop-flags.conf"

lines=()
if [[ -f "${flags_file}" ]]; then
    mapfile -t lines < "${flags_file}"
fi

flags=()
for line in "${lines[@]}"; do
    if [[ ! "${line}" =~ ^[[:space:]]*#.* ]] && [[ -n "${line}" ]]; then
        flags+=("${line}")
    fi
done

# The /usr/bin/electron wrapper sets ELECTRON_FORCE_IS_PACKAGED=true, which
# the app needs to resolve its resources (see PKGBUILD).
exec /usr/bin/electron /usr/lib/claude-desktop/resources/app.asar "${flags[@]}" "$@"
