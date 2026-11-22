#!/bin/bash
set -euo pipefail
shopt -s nullglob

fail() {
    printf '%s\n' "$*" >&2
    exit 1
}

[[ $# -eq 1 ]] || fail "Usage: $0 DATABASE_PATH (pass an empty string for a confirmed new release)"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT must name the step output file}"
command -v vercmp >/dev/null || fail "Arch Linux vercmp is required."

db_path=$1
work_dir=$(mktemp -d)
trap 'rm -rf -- "$work_dir"' EXIT

declare -A db_versions=()
if [[ -n "$db_path" ]]; then
    [[ -f "$db_path" && -s "$db_path" ]] || fail "Repository database is missing or empty: $db_path"
    gzip -t -- "$db_path" || fail "Invalid gzip repository database: $db_path"
    mkdir -- "$work_dir/db"
    tar -xzf "$db_path" -C "$work_dir/db" || fail "Could not extract repository database: $db_path"

    db_entries=("$work_dir"/db/*)
    ((${#db_entries[@]} > 0)) || fail "Repository database contains no packages: $db_path"
    for entry in "${db_entries[@]}"; do
        desc=$entry/desc
        [[ -d "$entry" && ! -L "$entry" && -f "$desc" && ! -L "$desc" ]] ||
            fail "Missing package description in repository database: ${entry##*/}"

        metadata=$(awk '
            { sub(/\r$/, "") }
            $0 == "%NAME%" {
                if (++names != 1 || getline != 1) exit 1
                sub(/\r$/, "")
                name = $0
            }
            $0 == "%VERSION%" {
                if (++versions != 1 || getline != 1) exit 1
                sub(/\r$/, "")
                version = $0
            }
            END {
                if (names != 1 || name !~ /^[a-z0-9@_+][a-z0-9@._+-]*$/ ||
                    versions != 1 || version !~ /^([0-9]+:)?[^[:space:]\/:%-]+-[0-9]+(\.[0-9]+)?$/) exit 1
                print name "\t" version
            }
        ' "$desc") || fail "Invalid package description in repository database: ${entry##*/}"

        IFS=$'\t' read -r db_name db_version <<< "$metadata"
        [[ -z "${db_versions[$db_name]-}" ]] || fail "Duplicate package in repository database: $db_name"
        db_versions[$db_name]=$db_version
    done
    printf 'Read %s packages from the repository database.\n' "${#db_versions[@]}"
else
    echo "New release confirmed. Starting with an empty repository database."
fi

echo "Checking upstream versions..."
if ! nvchecker -c nvchecker.toml --logger json --failures > "$work_dir/nvchecker.log"; then
    cat "$work_dir/nvchecker.log" >&2
    fail "Upstream version checks failed."
fi

recipe_value() {
    local value
    value=$(sed -n "s/^$2=//p" "$1")
    case "$value" in
        \'*\') value=${value:1:-1} ;;
        \"*\") value=${value:1:-1} ;;
    esac
    printf '%s\n' "$value"
}

compare_versions() {
    local comparison
    comparison=$(vercmp "$1" "$2") || fail "Could not compare versions $1 and $2."
    [[ "$comparison" == -1 || "$comparison" == 0 || "$comparison" == 1 ]] ||
        fail "Unexpected output from vercmp: $comparison"
    printf '%s\n' "$comparison"
}

build_list=()
changed_recipes=()
for pkgbuild_path in */PKGBUILD; do
    pkg_dir=${pkgbuild_path%/*}
    [[ "$pkg_dir" != unused && -f "$pkgbuild_path" && ! -L "$pkgbuild_path" ]] || continue

    pkgname=$(recipe_value "$pkgbuild_path" pkgname)
    pkgver=$(recipe_value "$pkgbuild_path" pkgver)
    pkgrel=$(recipe_value "$pkgbuild_path" pkgrel)
    epoch=$(recipe_value "$pkgbuild_path" epoch)
    [[ "$pkgname" =~ ^[a-z0-9@_+][a-z0-9@._+-]*$ &&
       "$pkgver" =~ ^[a-zA-Z0-9._+]+$ &&
       "$pkgrel" =~ ^[0-9]+(\.[0-9]+)?$ &&
       ( -z "$epoch" || "$epoch" =~ ^[0-9]+$ ) ]] ||
        fail "Invalid package name or version in $pkgbuild_path."

    if ! upstream_ver=$(jq -ers --arg name "$pkgname" '
        map(select(.name == $name and .version != null)) | last | .version | strings
    ' "$work_dir/nvchecker.log") || [[ ! "$upstream_ver" =~ ^[a-zA-Z0-9._+]+$ ]]; then
        cat "$work_dir/nvchecker.log" >&2
        fail "[$pkgname] nvchecker returned no valid upstream version."
    fi

    db_version=${db_versions[$pkgname]-}
    comparison=$(compare_versions "$upstream_ver" "$pkgver")
    if [[ "$comparison" == 1 ]]; then
        candidate_version="${epoch:+$epoch:}$upstream_ver-1"
        if [[ -n "$db_version" ]]; then
            comparison=$(compare_versions "$candidate_version" "$db_version")
            if [[ "$comparison" == -1 ]]; then
                echo "[$pkgname] Published version $db_version is newer than candidate $candidate_version."
                continue
            fi
        fi

        echo "[$pkgname] Upstream update: $pkgver -> $upstream_ver"
        staged_recipe=$work_dir/staged/$pkgbuild_path
        mkdir -p -- "${staged_recipe%/*}"
        cp -p -- "$pkgbuild_path" "$staged_recipe"
        sed -i -e "s/^pkgver=.*/pkgver=$upstream_ver/" -e 's/^pkgrel=.*/pkgrel=1/' "$staged_recipe"
        if [[ -f "$pkg_dir/update.sh" ]]; then
            bash "$pkg_dir/update.sh" "$staged_recipe" ||
                fail "[$pkgname] Could not update the package recipe."
        fi
        changed_recipes+=("$pkgbuild_path")
        build_list+=("$pkg_dir")
        continue
    fi

    local_version="${epoch:+$epoch:}$pkgver-$pkgrel"
    if [[ -z "$db_version" ]]; then
        echo "[$pkgname] Missing from the repository database. Queued for build."
        build_list+=("$pkg_dir")
        continue
    fi

    comparison=$(compare_versions "$local_version" "$db_version")
    if [[ "$comparison" == 1 ]]; then
        echo "[$pkgname] Local version $local_version is newer than published version $db_version. Queued for build."
        build_list+=("$pkg_dir")
    else
        echo "[$pkgname] Published version $db_version is current."
    fi
done

# Apply recipe edits only after checking all versions and running package hooks.
for pkgbuild_path in "${changed_recipes[@]}"; do
    mv -- "$work_dir/staged/$pkgbuild_path" "$pkgbuild_path"
done

if ((${#build_list[@]} == 0)); then
    echo "No updates or builds required."
    echo "BUILD_REQUIRED=false" >> "$GITHUB_OUTPUT"
else
    json_list=$(printf '%s\n' "${build_list[@]}" | jq -R . | jq -sc .)
    printf 'Build list: %s\n' "$json_list"
    printf 'BUILD_REQUIRED=true\nBUILD_PACKAGES=%s\n' "$json_list" >> "$GITHUB_OUTPUT"
fi
