# Shelter Arch package repository

This repository builds x86_64 packages for Antigravity, Claude Desktop, Microsoft
Edge, Obsidian, and Visual Studio Code. The `x86_64` GitHub release hosts the
packages and pacman indexes. Recipes under `.unused/` are excluded.

- **Arch Package CI/CD** checks upstream versions on its schedule or when requested
  from Actions. Manual runs can build all active recipes and publish new package filenames.
  Bump `pkgrel` for
  packaging changes to an already published version. The workflow refuses to
  overwrite a package filename with different bytes.
- **Check Orphaned Packages** previews the database entries and assets it would
  remove. Review the list before rerunning with **Apply removals**. The legacy
  ChatGPT package is explicitly retained.
- **Rebuild Repository Database** regenerates both indexes from the available
  package assets. Use it to recover damaged indexes or an interrupted database
  upload. Review the release assets first since this reindexes the newest
  available version of every package present.

The release workflows run one at a time. CI uploads new packages before
publishing the indexes and verifies each uploaded index file. GitHub replaces
index assets individually, so a failed upload can leave the indexes out of sync.
Retain older package assets until clients have had time to refresh their indexes.
