#!/bin/bash
set -e

# Run nvchecker (using config file)
echo "Running nvchecker..."
nvchecker -c nvchecker.toml --logger json > nvchecker.log 2>&1 || true

# Array to store packages requiring updates
BUILD_LIST=()

# Parse updated package info from nvchecker log
while read -r name version; do
    if [ -z "$name" ]; then continue; fi
    
    if [ -d "$name" ] && [ -f "$name/PKGBUILD" ]; then
        current_ver=$(grep "^pkgver=" "$name/PKGBUILD" | cut -d'=' -f2)

        if [ "$current_ver" == "$version" ]; then
            echo "Skipping $name: Already at version $version"
            continue
        fi

        echo "Update detected for $name: $current_ver -> $version"
        echo "Updating PKGBUILD for $name..."
        
        # Go to directory and run sed
        (
            cd "$name"
            # Update version
            sed -i "s/^pkgver=.*/pkgver=${version}/" PKGBUILD
            # Reset pkgrel 
            sed -i "s/^pkgrel=.*/pkgrel=1/" PKGBUILD
        )
        # Add to build list
        BUILD_LIST+=("$name")
    else
        echo "Warning: Directory or PKGBUILD not found for $name"
    fi
done < <(grep '"event": "updated"' nvchecker.log | jq -r '.name + " " + .version')

# Output results (JSON array for GitHub Actions)
if [ ${#BUILD_LIST[@]} -eq 0 ]; then
    echo "No updates found."
    echo "BUILD_REQUIRED=false" >> "$GITHUB_OUTPUT"
else
    # Convert to JSON array (Compact mode: -c to ensure single line)
    JSON_LIST=$(printf '%s\n' "${BUILD_LIST[@]}" | jq -R . | jq -s -c .)
    echo "Build List: $JSON_LIST"
    
    echo "BUILD_REQUIRED=true" >> "$GITHUB_OUTPUT"
    echo "BUILD_PACKAGES=$JSON_LIST" >> "$GITHUB_OUTPUT"
fi

rm -f nvchecker.log
