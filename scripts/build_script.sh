#!/bin/bash
set -euo pipefail

pacman -Syu --noconfirm pacman-contrib jq
useradd builduser -m
printf 'builduser ALL=(root) NOPASSWD: /usr/bin/pacman\n' > /etc/sudoers.d/builduser
chmod 0440 /etc/sudoers.d/builduser
sed -i 's/ debug/ !debug/g' /etc/makepkg.conf
chown -R builduser:builduser /github/workspace

cd /github/workspace
mkdir -p release_dist
jq -e 'type == "array" and length > 0 and all(.[]; type == "string" and test("^[a-zA-Z0-9][a-zA-Z0-9._+-]*$") and . != "unused")' <<< "$PACKAGES" > /dev/null
package_dirs=$(jq -r '.[]' <<< "$PACKAGES")

shopt -s nullglob
while IFS= read -r pkg_dir; do
    cd "/github/workspace/$pkg_dir"
    [[ -f PKGBUILD ]]
    echo "Building package: $pkg_dir"
    su builduser -c 'updpkgsums'
    su builduser -c 'makepkg --printsrcinfo > .SRCINFO'
    su builduser -c 'makepkg -s -c --noconfirm'
    packages=(*.pkg.tar.zst)
    if (( ${#packages[@]} == 0 )); then
        echo "No package file built for $pkg_dir" >&2
        exit 1
    fi
    mv -- "${packages[@]}" /github/workspace/release_dist/
done <<< "$package_dirs"
