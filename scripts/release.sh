#!/bin/bash
set -euo pipefail

tag=x86_64
dist=release_dist
db=shelter-arch-aur.db
files=shelter-arch-aur.files
assets="$dist/assets.json"
release="$dist/release.json"
indexes=("$db.tar.gz" "$files.tar.gz" "$files" "$db")
mkdir -p "$dist"

refresh_assets() {
    gh api --paginate "repos/$GITHUB_REPOSITORY/releases/$(jq -er .id "$release")/assets" |
        jq -s 'add // []' > "$assets"
}

download_indexes() {
    gh release download "$tag" -p "$db.tar.gz" -p "$files.tar.gz" -p "$db" -p "$files" -D "$dist"
    cmp "$dist/$db" "$dist/$db.tar.gz"
    cmp "$dist/$files" "$dist/$files.tar.gz"
    python3 scripts/release-index.py verify "$dist" "$assets"
}

publish_indexes() (
    python3 scripts/release-index.py verify "$dist" "$assets"
    local verification
    verification=$(mktemp -d)
    trap 'rm -rf -- "$verification"' EXIT
    local name
    for name in "${indexes[@]}"; do
        gh release upload "$tag" "$dist/$name" --clobber
        gh release download "$tag" -p "$name" -D "$verification"
        cmp "$dist/$name" "$verification/$name"
    done
)

case "${1:?expected a release operation}" in
    fetch)
        # A successful list with no matching tag is the only bootstrap case.
        gh api --paginate "repos/$GITHUB_REPOSITORY/releases" |
            jq -s --arg tag "$tag" '(add // []) | map(select(.tag_name == $tag)) | first // null' > "$release"
        if [[ $(cat "$release") != null ]]; then
            refresh_assets
            download_indexes
        fi
        ;;
    publish)
        if [[ $(cat "$release") == null ]]; then
            gh release create "$tag" --target "$(git rev-parse HEAD)" --title "Arch Linux Repository ($tag)" --notes "Arch Linux AUR Repository"
            gh api "repos/$GITHUB_REPOSITORY/releases/tags/$tag" > "$release"
        fi
        refresh_assets
        shopt -s nullglob
        for package in "$dist"/*.pkg.tar.zst; do
            name=${package##*/}
            existing=$(jq -r --arg name "$name" '.[] | select(.name == $name) | .digest // "missing digest"' "$assets")
            if [[ -n "$existing" ]]; then
                checksum=$(sha256sum "$package")
                if [[ "$existing" != "sha256:${checksum%% *}" ]]; then
                    echo "::error::Release already contains different bytes for $name. Bump pkgrel before replacing a package."
                    exit 1
                fi
            else
                gh release upload "$tag" "$package"
            fi
        done
        refresh_assets
        publish_indexes
        ;;
    rebuild)
        gh api "repos/$GITHUB_REPOSITORY/releases/tags/$tag" > "$release"
        refresh_assets
        gh release download "$tag" -p '*.pkg.tar.zst' -D "$dist"
        docker run --rm -v "$PWD:/repo" -w /repo/release_dist archlinux:base-devel bash /repo/scripts/manage-db.sh update
        publish_indexes
        ;;
    prune)
        gh api "repos/$GITHUB_REPOSITORY/releases/tags/$tag" > "$release"
        refresh_assets
        download_indexes
        python3 scripts/release-index.py plan "$dist" "$assets"
        echo "Database entries to remove:"
        cat "$dist/pkgs_to_remove.txt"
        echo "Release assets to remove:"
        cat "$dist/assets_to_remove.txt"
        [[ ${2:-false} == true ]] || exit 0

        if [[ -s "$dist/pkgs_to_remove.txt" ]]; then
            docker run --rm -v "$PWD:/repo" -w /repo/release_dist archlinux:base-devel bash /repo/scripts/manage-db.sh remove
            publish_indexes
        fi
        while IFS= read -r asset; do
            gh release delete-asset "$tag" "$asset" --yes
        done < "$dist/assets_to_remove.txt"
        ;;
    *)
        echo "Unknown release operation: $1" >&2
        exit 2
        ;;
esac
