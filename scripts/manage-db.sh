#!/bin/bash
# Consolidated script for Arch Linux Repository Database management
# Handles adding built packages and removing orphaned ones.

set -eu

ACTION=${1:-"update"} # update (add new pkgs) or remove (using pkgs_to_remove.txt)
DB_NAME="shelter-arch-aur.db.tar.gz"
FILES_DB="shelter-arch-aur.files.tar.gz"

echo ">> Database Management: Action=$ACTION" >&2

case "$ACTION" in
  "update")
    shopt -s nullglob
    pkgs=(*.pkg.tar.zst)
    if [ ${#pkgs[@]} -gt 0 ]; then
      echo ":: Adding/Updating ${#pkgs[@]} packages in $DB_NAME..." >&2
      # We removed -n to ensure metadata (size/checksums) is refreshed for updates
      repo-add "$DB_NAME" "${pkgs[@]}"
    else
      echo ":: No .pkg.tar.zst files found to add." >&2
    fi
    ;;

  "remove")
    if [ -s "pkgs_to_remove.txt" ]; then
      mapfile -t to_remove < <(sort -u pkgs_to_remove.txt)
      if [ ${#to_remove[@]} -gt 0 ]; then
        echo ":: Removing ${#to_remove[@]} packages from $DB_NAME..." >&2
        repo-remove "$DB_NAME" "${to_remove[@]}" || true
      fi
      rm "pkgs_to_remove.txt"
    else
      echo ":: No pkgs_to_remove.txt found or file is empty." >&2
    fi
    ;;

  *)
    echo "Error: Unknown action '$ACTION'. Use 'update' or 'remove'." >&2
    exit 1
    ;;
esac

# ------------------------------------------------------------------------------
# Finalize: Convert symlinks created by repo-add/remove to regular files
# This prevents "same file" errors and ensures pacman downloads the actual DB
# ------------------------------------------------------------------------------
for base in "shelter-arch-aur.db" "shelter-arch-aur.files"; do
  if [ -L "$base" ] || [ -f "$base" ]; then
    echo ":: Finalizing $base (converting to regular file)..." >&2
    rm -f "$base"
    cp -f "$base.tar.gz" "$base"
  fi
done

echo ">> Database management complete." >&2
