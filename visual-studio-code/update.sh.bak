#!/bin/bash
set -euo pipefail

pkgbuild_path="${1:-PKGBUILD}"
pkgver=$(grep "^pkgver=" "$pkgbuild_path" | cut -d'=' -f2 | tr -d '"' | tr -d "'")
current_electron=$(grep "^_electron=" "$pkgbuild_path" | cut -d'=' -f2 | tr -d '"' | tr -d "'")

npmrc_content=$(curl -sL "https://raw.githubusercontent.com/microsoft/vscode/${pkgver}/.npmrc" 2>/dev/null || true)
if [[ -z "$npmrc_content" ]] || [[ "$npmrc_content" == *"404"* ]]; then
    npmrc_content=$(curl -sL "https://raw.githubusercontent.com/microsoft/vscode/v${pkgver}/.npmrc" 2>/dev/null || true)
fi

electron_major=$(echo "$npmrc_content" | awk -F= '$1=="target"{gsub(/"|\..*/, "", $2); print $2}')

if [ -n "$electron_major" ]; then
    target_electron="electron${electron_major}"
    if [ -n "$current_electron" ] && [ "$current_electron" != "$target_electron" ]; then
        echo "[visual-studio-code] Updating Electron dependency: $current_electron -> $target_electron" >&2
        sed -i "s/^_electron=.*/_electron=${target_electron}/" "$pkgbuild_path"
    fi
fi
