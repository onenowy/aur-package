#!/bin/bash
# Check and clean up orphaned packages from GitHub Release
# Orphan = package exists in release but not in local PKGBUILD directories

set -e

echo "Checking for orphaned packages..."

# 1. Get list of valid local package directories (exclude scripts folder)
find . -maxdepth 2 -name PKGBUILD -not -path './scripts/*' -printf '%h\n' | sed 's|./||' | sort -u > local_pkgs.txt

# 2. Get list of remote .zst assets from GitHub Release
gh release view x86_64 --json assets -q '.assets[].name' | grep '\.pkg\.tar\.zst$' | sort > remote_assets.txt || touch remote_assets.txt

# 3. Download DB to check for DB-only orphans
mkdir -p release_dist
gh release download x86_64 -p "shelter-arch-aur.db.tar.gz" -D release_dist 2>/dev/null || true
gh release download x86_64 -p "shelter-arch-aur.files.tar.gz" -D release_dist 2>/dev/null || true

# 4. Extract package names from DB
if [ -f release_dist/shelter-arch-aur.db.tar.gz ]; then
  tar -tzf release_dist/shelter-arch-aur.db.tar.gz | grep -E '^[^/]+/$' | sed 's|/$||' | while read -r entry; do
    # entry is like "pkgname-version-release"
    # Extract pkgname (remove last 2 parts: version-release)
    echo "$entry" | rev | cut -d- -f3- | rev
  done | sort -u > db_pkgs.txt
else
  touch db_pkgs.txt
fi

# 5. Find orphans from both sources
touch pkgs_to_remove.txt

# 5a. From .zst files
while read -r asset; do
  [ -z "$asset" ] && continue
  basename=${asset%.pkg.tar.zst}
  pkgname=$(echo "$basename" | rev | cut -d- -f4- | rev)

  if ! grep -Fxq "$pkgname" local_pkgs.txt; then
    echo ":: Orphan detected (zst): $pkgname (File: $asset)"
    gh release delete-asset x86_64 "$asset" -y
    echo "$pkgname" >> pkgs_to_remove.txt
  fi
done < remote_assets.txt

# 5b. From DB (packages in DB but not in local)
while read -r pkgname; do
  [ -z "$pkgname" ] && continue
  if ! grep -Fxq "$pkgname" local_pkgs.txt; then
    if ! grep -Fxq "$pkgname" pkgs_to_remove.txt; then
      echo ":: Orphan detected (DB only): $pkgname"
      echo "$pkgname" >> pkgs_to_remove.txt
    fi
  fi
done < db_pkgs.txt

# 6. Output result
if [ -s pkgs_to_remove.txt ]; then
  mv pkgs_to_remove.txt release_dist/
  echo "ORPHANS_REMOVED=true"
else
  echo "ORPHANS_REMOVED=false"
fi
