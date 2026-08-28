#!/bin/bash
set -euo pipefail

pkgbuild_path="${1:-PKGBUILD}"
pkgver=$(grep "^pkgver=" "$pkgbuild_path" | cut -d'=' -f2 | tr -d '"' | tr -d "'")
current_build=$(grep "^_build=" "$pkgbuild_path" | cut -d'=' -f2 | tr -d '"' | tr -d "'")

# Fetch latest releases JSON from official updater endpoint
releases_json=$(curl -sL "https://antigravity-hub-auto-updater-974169037036.us-central1.run.app/releases" 2>/dev/null || true)

if [[ -n "$releases_json" ]] && [[ "$releases_json" == *"execution_id"* ]]; then
    target_build=$(echo "$releases_json" | jq -r --arg v "$pkgver" '.[] | select(.version == $v) | .execution_id // empty' 2>/dev/null | tr -d '/')
    
    # If not found for current pkgver, fallback to the latest version in the releases array
    if [[ -z "$target_build" ]]; then
        target_build=$(echo "$releases_json" | jq -r '.[0].execution_id // empty' 2>/dev/null | tr -d '/')
    fi

    if [[ -n "$target_build" ]] && [[ "$current_build" != "$target_build" ]]; then
        echo "[antigravity] Updating build ID: $current_build -> $target_build" >&2
        sed -i "s/^_build=.*/_build=${target_build}/" "$pkgbuild_path"
    fi
fi
