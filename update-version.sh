#!/bin/bash

# This script updates the package version if a new version is available
set -euxo pipefail


UPDATE_STATE="false"

# Get channel
PKG="microsoft-edge-stable"

# Get latest version
VER=$(curl -sSf https://packages.microsoft.com/repos/edge/dists/stable/main/binary-amd64/Packages |
    grep -A6 "Package: ${PKG}" |
    awk '/Version/{print $2}' |
    cut -d '-' -f1 |
    sort -rV |
    head -n1)

# Insert latest version into PKGBUILD and update hashes
sed -i \
    -e "s/^pkgver=.*/pkgver=${VER}/" \
    PKGBUILD

# Check whether this changed anything
if (git diff --exit-code PKGBUILD); then
    echo "$UPDATE_STATE"
    exit 0
fi

UPDATE_STATE="${VER}"

# updpkgsums
SUM256=$(curl -sSf https://packages.microsoft.com/repos/edge/dists/stable/main/binary-amd64/Packages |
    grep -A15 "Package: ${PKG}" |
    grep -A14 "Version: ${VER}" |
    awk '/SHA256/{print $2}' |
    head -n1)

# Insert latest shasum into PKGBUILD and update hashes
sed -i \
    -e "s/^sha256sums=('.*/sha256sums=('${SUM256}'/" \
    PKGBUILD

# Reset pkgrel
sed -i \
    -e 's/pkgrel=.*/pkgrel=1/' \
    PKGBUILD

echo "$UPDATE_STATE"
