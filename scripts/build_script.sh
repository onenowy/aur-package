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
REQUIRED_DEPS_LIST=""

echo ">> Loading dependencies from $DEP_FILE..."

if [[ -f "$DEP_FILE" ]]; then
    # 1. Get all keys (package names) from the JSON file
    PKG_KEYS=$(jq -r 'keys[]' "$DEP_FILE")

    for pkg in $PKG_KEYS; do
        # 2. Extract dependencies array and join them with spaces
        deps=$(jq -r ".[\"$pkg\"] | join(\" \")" "$DEP_FILE")
        
        # 3. Assign to associative array for build ordering
        SPECIAL_DEPS["$pkg"]="$deps"
        echo "   [Config] Loaded dependency: '$pkg' requires '$deps'"
    done
    
    # [NEW] Create a flat list of ALL packages that are required as dependencies
    # Extract all values from JSON and remove duplicates to know which ones MUST be installed
    REQUIRED_DEPS_LIST=$(jq -r 'values[] | .[]' "$DEP_FILE" | sort -u)
    echo "---------------------------------------------------"
    echo "   [Config] Packages marked as required dependencies:"
    echo "$REQUIRED_DEPS_LIST"
    echo "---------------------------------------------------"
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
BUILT_PKGS=()

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
  
  # Enable nullglob to handle cases with no matching files
  shopt -s nullglob
  pkg_files=(*.pkg.tar.zst)
  shopt -u nullglob
  
  if [ ${#pkg_files[@]} -gt 0 ]; then
      
      # Extract pkgname from .SRCINFO to check if it's a required dependency
      current_pkgname=$(grep "pkgname = " .SRCINFO | head -n1 | cut -d= -f2 | xargs)
      
      # [NEW] Check if this package is required by others (listed in JSON values)
      # Only install locally if it's in the REQUIRED_DEPS_LIST
      IS_REQUIRED=false
      if [[ -n "$REQUIRED_DEPS_LIST" ]]; then
          if echo "$REQUIRED_DEPS_LIST" | grep -Fqx "$current_pkgname"; then
              IS_REQUIRED=true
          fi
      fi
      
      if [ "$IS_REQUIRED" = true ]; then
          echo ":: Installing $current_pkgname locally (Required by other packages)..."
          pacman -U --noconfirm "${pkg_files[@]}"
      else
          echo ":: Skipping local installation for $current_pkgname (Not listed as a dependency in JSON)."
      fi

      # Add to list of built packages
      BUILT_PKGS+=("$current_pkgname")
      
      # Move artifacts to release directory
      mv "${pkg_files[@]}" ../release_dist/
  else
      echo "Error: No package file built for $pkg_dir"
      exit 1
  fi
  
  cd /github/workspace
done

# Output list of built packages to GitHub Actions output
if [ -n "$GITHUB_OUTPUT" ]; then
    echo "UPDATED_PKGNAMES=${BUILT_PKGS[*]}" >> "$GITHUB_OUTPUT"
fi
