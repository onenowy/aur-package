#!/bin/bash
# Check and clean up orphaned packages and old versions from GitHub Release
# 1. Orphan = package exists in release but not in local PKGBUILD directories
# 2. Old Version = package version in release doesn't match local PKGBUILD version

set -eu

echo ">> Checking for orphaned and old packages..." >&2

# 1. Get list of valid local package names and their current versions
# Format: pkgname version-release
touch local_pkgs_full.txt
: > local_pkgs_full.txt

find . -maxdepth 2 -name PKGBUILD -not -path './scripts/*' | while read -r pkgbuild; do
  pkgname=$(grep "^pkgname=" "$pkgbuild" | cut -d'=' -f2 | tr -d '"' | tr -d "'")
  pkgver=$(grep "^pkgver=" "$pkgbuild" | cut -d'=' -f2 | tr -d '"' | tr -d "'")
  pkgrel=$(grep "^pkgrel=" "$pkgbuild" | cut -d'=' -f2 | tr -d '"' | tr -d "'")
  echo "$pkgname $pkgver-$pkgrel" >> local_pkgs_full.txt
done
sort -u local_pkgs_full.txt -o local_pkgs_full.txt
cut -d' ' -f1 local_pkgs_full.txt | sort -u > local_pkgs_names.txt

# 2. Get list of remote .zst assets from GitHub Release
gh release view x86_64 --json assets -q '.assets[].name' | grep '\.pkg\.tar\.zst$' | sort > remote_assets.txt || touch remote_assets.txt

# 3. Download DB to check for DB-only orphans
mkdir -p release_dist
gh release download x86_64 -p "shelter-arch-aur.db.tar.gz" -D release_dist 2>/dev/null || true
gh release download x86_64 -p "shelter-arch-aur.files.tar.gz" -D release_dist 2>/dev/null || true

# 4. Extract package names and versions from DB
if [ -f release_dist/shelter-arch-aur.db.tar.gz ]; then
  tar -tzf release_dist/shelter-arch-aur.db.tar.gz | grep -E '^[^/]+/$' | sed 's|/$||' | sort -u > db_pkgs_full.txt
else
  touch db_pkgs_full.txt
fi

# 5. Find orphans and old versions to remove
touch pkgs_to_remove_from_db.txt
: > pkgs_to_remove_from_db.txt

# 5a. Clean up Assets (Files in Release)
while read -r asset; do
  [ -z "$asset" ] && continue
  basename=${asset%.pkg.tar.zst}
  # Extract pkgname and version from filename: pkgname-ver-rel-arch
  pkgname=$(echo "$basename" | rev | cut -d- -f4- | rev)
  pkgver_rel=$(echo "$basename" | rev | cut -d- -f2,3 | rev)

  # Check if it's an orphan (no local PKGBUILD)
  if ! grep -Fxq "$pkgname" local_pkgs_names.txt; then
    echo ":: Orphan detected (Artifact): $pkgname (File: $asset)" >&2
    gh release delete-asset x86_64 "$asset" -y >&2
    echo "$pkgname" >> pkgs_to_remove_from_db.txt
    continue
  fi

  # Check if it's an old version
  current_ver=$(grep "^$pkgname " local_pkgs_full.txt | cut -d' ' -f2)
  if [ "$pkgver_rel" != "$current_ver" ]; then
    echo ":: Old version detected (Artifact): $pkgname-$pkgver_rel (Current: $current_ver). Deleting $asset" >&2
    gh release delete-asset x86_64 "$asset" -y >&2
  fi
done < remote_assets.txt

# 5b. Clean up DB entries
while read -r entry; do
  [ -z "$entry" ] && continue
  # entry is "pkgname-version-release"
  pkgname=$(echo "$entry" | rev | cut -d- -f3- | rev)
  pkgver_rel=$(echo "$entry" | rev | cut -d- -f1,2 | rev)

  if ! grep -Fxq "$pkgname" local_pkgs_names.txt; then
    echo ":: Orphan detected (Database): $pkgname" >&2
    echo "$pkgname" >> pkgs_to_remove_from_db.txt
  elif [ "$pkgver_rel" != "$(grep "^$pkgname " local_pkgs_full.txt | cut -d' ' -f2)" ]; then
    echo ":: Old version detected (Database): $entry" >&2
    echo "$pkgname" >> pkgs_to_remove_from_db.txt
  fi
done < db_pkgs_full.txt

# 6. Output result
if [ -s pkgs_to_remove_from_db.txt ]; then
  sort -u pkgs_to_remove_from_db.txt -o pkgs_to_remove_from_db.txt
  mv pkgs_to_remove_from_db.txt release_dist/pkgs_to_remove.txt
  echo "ORPHANS_REMOVED=true"
else
  echo "ORPHANS_REMOVED=false"
fi

# Cleanup
rm -f local_pkgs_full.txt local_pkgs_names.txt remote_assets.txt db_pkgs_full.txt
