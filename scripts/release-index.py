"""Read pacman indexes and check the package assets they reference."""

import json
from pathlib import Path
import sys
import tarfile


KEEP_PACKAGES = {"chatgpt"}


def read_index(path):
    packages = {}
    with tarfile.open(path, "r:gz") as archive:
        for member in archive:
            if not member.isfile() or not member.name.endswith("/desc"):
                continue
            fields = dict(
                section.split("\n", 1)
                for section in archive.extractfile(member).read().decode().strip().split("\n\n")
            )
            name = fields["%NAME%"]
            filename = fields["%FILENAME%"]
            checksum = fields["%SHA256SUM%"]
            if name in packages or Path(filename).name != filename:
                raise ValueError(f"Invalid package entry: {name}, {filename}")
            packages[name] = (filename, checksum)
    if not packages:
        raise ValueError(f"Empty package index: {path}")
    return packages


def main():
    action, directory, assets_path = sys.argv[1:]
    directory = Path(directory)
    assets = {asset["name"]: asset for asset in json.loads(Path(assets_path).read_text())}
    packages = read_index(directory / "shelter-arch-aur.db.tar.gz")
    files = read_index(directory / "shelter-arch-aur.files.tar.gz")
    if packages != files:
        raise ValueError("Package and files indexes disagree")

    for filename, checksum in packages.values():
        asset = assets.get(filename)
        if not asset or asset["state"] != "uploaded" or asset["digest"] != f"sha256:{checksum}":
            raise ValueError(f"Missing or mismatched release asset: {filename}")

    if action == "plan":
        active = {
            line.split("=", 1)[1].strip()
            for path in Path.cwd().glob("*/.SRCINFO")
            if path.parent.name != "unused" and (path.parent / "PKGBUILD").is_file()
            for line in path.read_text().splitlines()
            if line.startswith("pkgname = ")
        }
        if not active:
            raise ValueError("No active package definitions found")
        retired = sorted(packages.keys() - active - KEEP_PACKAGES)
        referenced = {filename for filename, _ in packages.values()}
        obsolete = {
            filename for filename in assets.keys() - referenced
            if filename.endswith(".pkg.tar.zst")
            and filename.removesuffix(".pkg.tar.zst").rsplit("-", 3)[0] not in KEEP_PACKAGES
        }
        obsolete.update(packages[name][0] for name in retired)
        if retired and len(retired) == len(packages):
            raise ValueError("Refusing to remove every indexed package")
        (directory / "pkgs_to_remove.txt").write_text("".join(f"{name}\n" for name in retired))
        (directory / "assets_to_remove.txt").write_text("".join(f"{name}\n" for name in sorted(obsolete)))


if __name__ == "__main__":
    main()
