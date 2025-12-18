#!/bin/bash
set -e

# 1. Install system dependencies
pacman -Syu --noconfirm git pacman-contrib jq

# 2. Setup build user
useradd builduser -m
passwd -d builduser
printf 'builduser ALL=(ALL) ALL\n' | tee -a /etc/sudoers
chown -R builduser:builduser .

# 3. Optimization & Build Settings
echo 'MAKEFLAGS="-j$(nproc)"' >> /etc/makepkg.conf
echo 'CFLAGS="-march=x86-64-v3 -O3 -pipe -fno-plt"' >> /etc/makepkg.conf
echo 'CXXFLAGS="-march=x86-64-v3 -O3 -pipe -fno-plt"' >> /etc/makepkg.conf
echo 'RUSTFLAGS="-C opt-level=3 -C target-cpu=x86-64-v3"' >> /etc/makepkg.conf
# Disable debug packages
sed -i 's/ debug/ !debug/g' /etc/makepkg.conf

# 4. Prepare staging directory
mkdir -p release_dist

# 5. Dependency Sorting Logic
# Convert JSON input to a space-separated string
RAW_LIST=$(echo "$PACKAGES" | jq -r '.[]')

# [Auto-Fix] Inject dependencies for octopi if present
if echo "$RAW_LIST" | grep -q "^octopi$"; then
  echo ":: Octopi detected. Injecting dependencies (qt-sudo, alpm_octopi_utils)..."
  # Append dependencies to the list
  RAW_LIST="$RAW_LIST"$'\n'"alpm_octopi_utils"$'\n'"qt-sudo"
fi

# Define priority groups
# - Dependencies must be built FIRST
DEPS_FIRST="alpm_octopi_utils qt-sudo"
# - Dependents must be built LAST
DEPS_LAST="octopi"

BUILD_QUEUE=""

# Step A: Add Dependencies first (if they exist in the list)
for pkg in $DEPS_FIRST; do
  if echo "$RAW_LIST" | grep -q "^$pkg$"; then
    BUILD_QUEUE="$BUILD_QUEUE $pkg"
  fi
done

# Step B: Add general packages (excluding special ones)
for pkg in $RAW_LIST; do
  # Check if pkg is NOT in DEPS_FIRST and NOT in DEPS_LAST
  if [[ ! " $DEPS_FIRST $DEPS_LAST " =~ " $pkg " ]]; then
    BUILD_QUEUE="$BUILD_QUEUE $pkg"
  fi
done

# Step C: Add Dependents last
for pkg in $DEPS_LAST; do
  if echo "$RAW_LIST" | grep -q "^$pkg$"; then
    BUILD_QUEUE="$BUILD_QUEUE $pkg"
  fi
done

echo "Build Order: $BUILD_QUEUE"

# 6. Build Loop
for pkg in $BUILD_QUEUE; do
  echo "--------------------------------------"
  echo "Building package: $pkg"
  echo "--------------------------------------"
  
  TARGET_DIR="/github/workspace/$pkg"
  if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Directory $TARGET_DIR does not exist."
    exit 1
  fi
  
  cd "$TARGET_DIR"
  
  # Update checksums & Generate .SRCINFO
  su builduser -c 'updpkgsums'
  su builduser -c 'makepkg --printsrcinfo > .SRCINFO'
  
  # Build Package
  # -s: install missing deps from repos
  su builduser -c 'makepkg -s --noconfirm'
  
  # [CRITICAL] Install the built package locally!
  echo "Installing $pkg locally to satisfy future dependencies..."
  pacman -U --noconfirm *.pkg.tar.zst
  
  # Move artifacts to release folder
  mv *.pkg.tar.zst ../release_dist/
  
  cd /github/workspace
done
