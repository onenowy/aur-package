#!/bin/bash
set -euo pipefail

pkgbuild_path="${1:-PKGBUILD}"
pkgver=$(sed -n 's/^pkgver=//p' "$pkgbuild_path" | tr -d "\"'")
current_build=$(sed -n 's/^_build=//p' "$pkgbuild_path" | tr -d "\"'")
if [[ ! "$pkgver" =~ ^[a-zA-Z0-9._+]+$ || ! "$current_build" =~ ^[0-9]+$ ]]; then
    echo "[antigravity] Invalid pkgver or _build in $pkgbuild_path." >&2
    exit 1
fi

releases_url=https://antigravity-hub-auto-updater-974169037036.us-central1.run.app/releases
if ! target_build=$(curl -fsSL --retry 2 --max-time 30 "$releases_url" |
    jq -er --arg version "$pkgver" '
        [.[] | select(.version == $version) | .execution_id | tostring | gsub("^/+|/+$"; "")] | unique |
        if length == 1 and (.[0] | test("^[0-9]+$")) then .[0]
        else error("expected one numeric execution ID for version " + $version)
        end
    '
) || [[ ! "$target_build" =~ ^[0-9]+$ ]]; then
    echo "[antigravity] Could not resolve the build ID for version $pkgver." >&2
    exit 1
fi

if [[ "$current_build" != "$target_build" ]]; then
    echo "[antigravity] Updating build ID: $current_build -> $target_build" >&2
    sed -i "s/^_build=.*/_build=$target_build/" "$pkgbuild_path"
fi
