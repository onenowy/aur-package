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
    local larger=$(printf '%s
%s' "$v1" "$v2" | sort -V | tail -n1)
    if [ "$larger" = "$v1" ]; then return 0; else return 1; fi
}

# 1. Run nvchecker (upstream check)
echo "Running nvchecker..."
nvchecker -c nvchecker.toml --logger json > nvchecker.log 2>&1 || true

# 2. Get currently released packages from Repo Database
echo "Fetching repository database..."
mkdir -p db_tmp
touch db_versions.txt

if command -v gh >/dev/null; then
    # Download DB to get registered versions (including epoch)
    # We suppress output to avoid clutter
    # Try downloading the DB archive
    if gh release download x86_64 -p "shelter-arch-aur.db.tar.gz" -D db_tmp >/dev/null 2>&1; then
        echo "Database downloaded. Extracting..."
        tar -xf db_tmp/shelter-arch-aur.db.tar.gz -C db_tmp
        
        # Parse desc files for versions
        # Structure: db_tmp/pkgname-ver-rel/desc
        # Content contains:
        # %NAME%
        # pkgname
        # %VERSION%
        # epoch:ver-rel
        
        # Find all desc files and parse them into a key-value list (pkgname version)
        find db_tmp -name "desc" | while read -r desc_file; do
             awk '
                /%NAME%/ { getline; name=$0 }
                /%VERSION%/ { getline; version=$0 }
                END { if(name && version) print name " " version }
             ' "$desc_file" >> db_versions.txt
        done
    else
        echo "Warning: Could not download repository database (might not exist yet)."
    fi
else
    echo "Warning: 'gh' tool not found. Skipping release check."
fi

BUILD_LIST=()

echo "Checking local packages..."

# Iterate over all directories containing a PKGBUILD
for pkgbuild_path in */PKGBUILD; do
    pkg_dir=$(dirname "$pkgbuild_path")
    if [ "$pkg_dir" = "." ] || [ "$pkg_dir" = "scripts" ]; then continue; fi

    # Read PKGBUILD variables
    pkgname=$(grep "^pkgname=" "$pkgbuild_path" | cut -d'=' -f2 | tr -d '"' | tr -d "'")
    pkgver=$(grep "^pkgver=" "$pkgbuild_path" | cut -d'=' -f2)
    pkgrel=$(grep "^pkgrel=" "$pkgbuild_path" | cut -d'=' -f2)
    epoch=$(grep "^epoch=" "$pkgbuild_path" | cut -d'=' -f2 || echo "")

    if [ -z "$pkgname" ]; then continue; fi

    needs_build=false
    
    # --- Check 1: Upstream vs PKGBUILD ---
    upstream_ver=$(grep "\"name\": \"$pkgname\"" nvchecker.log | jq -r .version || echo "")

    if [ -n "$upstream_ver" ] && [ "$upstream_ver" != "null" ]; then
        if ver_gt "$upstream_ver" "$pkgver"; then
            echo "[$pkgname] Upstream update detected: $pkgver -> $upstream_ver"
            
            # Update PKGBUILD
            sed -i "s/^pkgver=.*/pkgver=${upstream_ver}/" "$pkgbuild_path"
            sed -i "s/^pkgrel=.*/pkgrel=1/" "$pkgbuild_path"
            
            pkgver=$upstream_ver
            pkgrel=1
            needs_build=true
        else
            echo "[$pkgname] Upstream ($upstream_ver) is not newer than local ($pkgver)."
        fi
    fi

    # --- Check 2: PKGBUILD vs Repo Database ---
    # Construct local full version string
    if [ -n "$epoch" ]; then
        local_full_ver="${epoch}:${pkgver}-${pkgrel}"
    else
        local_full_ver="${pkgver}-${pkgrel}"
    fi

    # Get DB version from our parsed list
    db_full_ver=$(grep "^$pkgname " db_versions.txt | cut -d' ' -f2 || echo "")

    if [ -z "$db_full_ver" ]; then
        echo "[$pkgname] Not in database. Marking for build."
        needs_build=true
    else
        # Check if Local > DB
        if ver_gt "$local_full_ver" "$db_full_ver"; then
            echo "[$pkgname] Local ($local_full_ver) > Repo ($db_full_ver). Marking for build."
            needs_build=true
        else
            echo "[$pkgname] Up to date with repo ($db_full_ver)."
        fi
    fi

    if [ "$needs_build" = true ]; then
        BUILD_LIST+=("$pkg_dir")
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
    JSON_LIST=$(printf '%s
' "${BUILD_LIST[@]}" | sort -u | jq -R . | jq -s -c .)
    echo "Build List: $JSON_LIST"
    
    echo "BUILD_REQUIRED=true" >> "$GITHUB_OUTPUT"
    echo "BUILD_PACKAGES=$JSON_LIST" >> "$GITHUB_OUTPUT"
fi