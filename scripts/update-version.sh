#!/bin/bash
set -e

# Function to compare Arch Linux versions (including epoch)
# Returns 0 if $1 > $2, 1 otherwise
ver_gt() {
    local v1=$1
    local v2=$2

    if [ "$v1" = "$v2" ]; then return 1; fi

    # Normalize versions: ensure both have an epoch (default 0)
    [[ "$v1" != *:* ]] && v1="0:$v1"
    [[ "$v2" != *:* ]] && v2="0:$v2"

    # Extract Epochs
    local e1=${v1%%:*}
    local e2=${v2%%:*}

    if [ "$e1" -gt "$e2" ]; then return 0; fi
    if [ "$e1" -lt "$e2" ]; then return 1; fi

    # If epochs are equal, compare version-release part using sort -V
    v1=${v1#*:}
    v2=${v2#*:}
    local larger=$(printf '%s\n%s' "$v1" "$v2" | sort -V | tail -n1)
    if [ "$larger" = "$v1" ]; then return 0; else return 1; fi
}

check_package() {
    local pkgbuild_path=$1
    local pkg_dir=$(dirname "$pkgbuild_path")
    
    # Skip non-package directories
    if [ "$pkg_dir" = "." ] || [ "$pkg_dir" = "scripts" ]; then return; fi

    # Read PKGBUILD variables
    local pkgname=$(grep "^pkgname=" "$pkgbuild_path" | cut -d'=' -f2 | tr -d '"' | tr -d "'")
    local pkgver=$(grep "^pkgver=" "$pkgbuild_path" | cut -d'=' -f2)
    local pkgrel=$(grep "^pkgrel=" "$pkgbuild_path" | cut -d'=' -f2)
    local epoch=$(grep "^epoch=" "$pkgbuild_path" | cut -d'=' -f2 || echo "")

    if [ -z "$pkgname" ]; then return; fi
    
    # --- Check 1: Upstream vs PKGBUILD ---
    # Extract version from nvchecker log (handle multiple lines/events, take last non-null)
    local upstream_ver=$(grep "\"name\": \"$pkgname\"" nvchecker.log | jq -r .version | grep -v "null" | tail -n1 || echo "")

    if [ -n "$upstream_ver" ]; then
        if ver_gt "$upstream_ver" "$pkgver"; then
            echo "[$pkgname] Upstream update detected: $pkgver -> $upstream_ver" >&2
            
            # Update PKGBUILD
            sed -i "s/^pkgver=.*/pkgver=${upstream_ver}/" "$pkgbuild_path"
            sed -i "s/^pkgrel=.*/pkgrel=1/" "$pkgbuild_path"
            
            # Since we updated the PKGBUILD, we definitely need to build.
            # Skip Check 2 as requested.
            echo "$pkg_dir"
            return
        else
            echo "[$pkgname] Upstream ($upstream_ver) is not newer than local ($pkgver)." >&2
        fi
    fi

    # --- Check 2: PKGBUILD vs Repo Database ---
    local local_full_ver="${pkgver}-${pkgrel}"
    if [ -n "$epoch" ]; then
        local_full_ver="${epoch}:${pkgver}-${pkgrel}"
    fi

    # Get DB version using awk for exact match
    local db_full_ver=$(awk -v pkg="$pkgname" '$1 == pkg {print $2; exit}' db_versions.txt)

    if [ -z "$db_full_ver" ]; then
        echo "[$pkgname] Not in database. Marking for build." >&2
        echo "$pkg_dir"
    else
        if ver_gt "$local_full_ver" "$db_full_ver"; then
            echo "[$pkgname] Local ($local_full_ver) > Repo ($db_full_ver). Marking for build." >&2
            echo "$pkg_dir"
        else
            echo "[$pkgname] Up to date with repo ($db_full_ver)." >&2
        fi
    fi
}

# 1. Run nvchecker (upstream check)
echo "Running nvchecker..."
nvchecker -c nvchecker.toml --logger json > nvchecker.log 2>&1 || true

# 2. Get currently released packages from Repo Database
echo "Fetching repository database..."
mkdir -p db_tmp
: > db_versions.txt # Create/Clear file

if gh release download x86_64 -p "shelter-arch-aur.db.tar.gz" -D db_tmp >/dev/null 2>&1; then
    echo "Database downloaded. Extracting..."
    tar -xf db_tmp/shelter-arch-aur.db.tar.gz -C db_tmp
    
    # Parse desc files for versions
    find db_tmp -name "desc" | while read -r desc_file; do
            awk '
            /%NAME%/ { getline; sub(/\r$/, ""); name=$0 }
            /%VERSION%/ { getline; sub(/\r$/, ""); version=$0 }
            END { if(name && version) print name " " version }
            ' "$desc_file" >> db_versions.txt
    done
    
    entry_count=$(wc -l < db_versions.txt)
    echo "Parsed $entry_count packages from repository database."
    if [ "$entry_count" -eq 0 ]; then
            echo "Warning: Database extracted but no packages found (check db_tmp content)."
            ls -R db_tmp | head -n 20
    fi
else
    echo "Warning: Could not download repository database (might not exist yet)."
fi

BUILD_LIST=()

echo "Checking local packages..."

# Iterate over all directories containing a PKGBUILD
for pkgbuild_path in */PKGBUILD; do
    # Capture output of check_package
    result=$(check_package "$pkgbuild_path")
    if [ -n "$result" ]; then
        BUILD_LIST+=("$result")
    fi
done

# Cleanup
rm -f nvchecker.log db_versions.txt
rm -rf db_tmp

# Output results for GitHub Actions
if [ ${#BUILD_LIST[@]} -eq 0 ]; then
    echo "No updates or builds required."
    echo "BUILD_REQUIRED=false" >> "$GITHUB_OUTPUT"
else
    # Deduplicate list and format as JSON
    JSON_LIST=$(printf '%s\n' "${BUILD_LIST[@]}" | sort -u | jq -R . | jq -s -c .)
    echo "Build List: $JSON_LIST"
    
    echo "BUILD_REQUIRED=true" >> "$GITHUB_OUTPUT"
    echo "BUILD_PACKAGES=$JSON_LIST" >> "$GITHUB_OUTPUT"
fi