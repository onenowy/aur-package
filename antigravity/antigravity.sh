#!/bin/bash

flags_file="${XDG_CONFIG_HOME:-$HOME/.config}/antigravity-flags.conf"

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
exec /usr/bin/electron /opt/Antigravity/resources/app.asar "${flags[@]}" "$@"
