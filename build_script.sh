#!/bin/bash
set -e

# ==============================================================================
# 1. System Setup
# ==============================================================================
# Install required tools (jq is essential for parsing the JSON file)
pacman -Syu --noconfirm git pacman-contrib jq

# Setup build user
useradd builduser -m
passwd -d builduser
printf 'builduser ALL=(ALL) ALL\n' | tee -a /etc/sudoers
chown -R builduser:builduser .

# Configure build optimization settings
echo 'MAKEFLAGS="-j$(nproc)"' >> /etc/makepkg.conf
echo 'CFLAGS="-march=x86-64-v3 -O3 -pipe -fno-plt"' >> /etc/makepkg.conf
echo 'CXXFLAGS="-march=x86-64-v3 -O3 -pipe -fno-plt"' >> /etc/makepkg.conf
echo 'RUSTFLAGS="-C opt-level=3 -C target-cpu=x86-64-v3"' >> /etc/makepkg.conf
sed -i 's/ debug/ !debug/g' /etc/makepkg.conf

# Create directory for built packages
mkdir -p release_dist

# ==============================================================================
# 2. Load Dependencies from JSON
# ==============================================================================
declare -A SPECIAL_DEPS
DEP_FILE="dependencies.json"

echo ">> Loading dependencies from $DEP_FILE..."

if [[ -f "$DEP_FILE" ]]; then
    # 1. Get all keys (package names) from the JSON file
    PKG_KEYS=$(jq -r 'keys[]' "$DEP_FILE")

    for pkg in $PKG_KEYS; do
        # 2. Extract dependencies array and join them with spaces
        # Example: ["a", "b"] -> "a b"
        deps=$(jq -r ".[\"$pkg\"] | join(\" \")" "$DEP_FILE")
        
        # 3. Assign to associative array
        SPECIAL_DEPS["$pkg"]="$deps"
        echo "   [Config] Loaded dependency: '$pkg' requires '$deps'"
    done
else
    echo "   [Warning] $DEP_FILE not found. Skipping custom dependency loading."
fi

# ==============================================================================
# 3. Calculate Build Order
# ==============================================================================
echo ">> Calculating build order..."

# Parse input packages (JSON -> space-separated string)
INPUT_PKGS=$(echo "$PACKAGES" | jq -r '.[]')

BUILD_QUEUE=()
declare -A ADDED_MAP  # Map to track added packages and prevent duplicates

# Recursive function to process packages and their dependencies
process_package() {
    local pkg_name=$1

    # Skip if already added to the queue
    if [[ -n "${ADDED_MAP[$pkg_name]}" ]]; then
        return
    fi

    # 1. Check if the package has special dependencies defined (Loaded from JSON)
    if [[ -n "${SPECIAL_DEPS[$pkg_name]}" ]]; then
        echo "   [Dependency] '$pkg_name' requires: ${SPECIAL_DEPS[$pkg_name]}"
        # Process dependencies first (recursive call)
        for dep in ${SPECIAL_DEPS[$pkg_name]}; do
            process_package "$dep"
        done
    fi

    # 2. Verify directory exists and add to queue
    if [[ -d "$pkg_name" ]]; then
        BUILD_QUEUE+=("$pkg_name")
        ADDED_MAP["$pkg_name"]=1
        echo "   [Queue] Added: $pkg_name"
    else
        echo "   [Warning] Package '$pkg_name' directory not found. Skipping."
    fi
}

# Process all input packages
for pkg in $INPUT_PKGS; do
    process_package "$pkg"
done

echo "--------------------------------------"
echo "Final Build Order: ${BUILD_QUEUE[*]}"
echo "--------------------------------------"

if [ ${#BUILD_QUEUE[@]} -eq 0 ]; then
    echo "No packages to build."
    exit 0
fi

# ==============================================================================
# 4. Build Loop
# ==============================================================================
for pkg_dir in "${BUILD_QUEUE[@]}"; do
  echo "--------------------------------------"
  echo "Building package: $pkg_dir"
  echo "--------------------------------------"
  
  TARGET_DIR="/github/workspace/$pkg_dir"
  cd "$TARGET_DIR"
  
  # Update checksums & Generate .SRCINFO
  su builduser -c 'updpkgsums'
  su builduser -c 'makepkg --printsrcinfo > .SRCINFO'
  
  # Build package
  # -s: install missing deps
  # -c: clean up work files (src/pkg directories) after build
  su builduser -c 'makepkg -s -c --noconfirm'
  
  # [IMPORTANT] Install the built package locally to satisfy future dependencies
  echo "Installing $pkg_dir locally to satisfy future dependencies..."
  
  # Enable nullglob to handle cases with no matching files
  shopt -s nullglob
  pkg_files=(*.pkg.tar.zst)
  shopt -u nullglob
  
  if [ ${#pkg_files[@]} -gt 0 ]; then
      pacman -U --noconfirm "${pkg_files[@]}"
      
      # [NEW] Record the package name for cleanup logic in CI
      # Extract pkgname from .SRCINFO
      current_pkgname=$(grep "pkgname = " .SRCINFO | head -n1 | cut -d= -f2 | xargs)
      echo "$current_pkgname" >> ../release_dist/updated_pkgnames.txt
      
      # Move artifacts to release directory
      mv "${pkg_files[@]}" ../release_dist/
  else
      echo "Error: No package file built for $pkg_dir"
      exit 1
  fi
  
  cd /github/workspace
done