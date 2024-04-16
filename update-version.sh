#!/bin/bash

# This script updates the package version if a new version is available
set -euxo pipefail


UPDATE_STATE="false"

# Get channel
PKG="microsoft-edge-stable"

# Get latest version
FILELISTS=$(curl -sSf "https://packages.microsoft.com/yumrepos/edge/repodata/repomd.xml" |
    xmllint --xpath 'string(//*[local-name()="data"][@type="filelists"]/*[local-name()="location"]/@href)' -)

VER=$(curl -sSf "https://packages.microsoft.com/yumrepos/edge/${FILELISTS}" |
    gzip -dc |
    xmllint --xpath 'string(//*[local-name()="package"][@name="microsoft-edge-stable"][last()]/*[local-name()="version"]/@ver)' -)

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
SUM256=$(curl -sSf "https://packages.microsoft.com/yumrepos/edge/${FILELISTS}" |
    gzip -dc |
    xmllint --xpath 'string(//*[local-name()="package"][@name="microsoft-edge-stable"][last()]/@pkgid)' -)

# Insert latest shasum into PKGBUILD and update hashes
sed -i \
    -e "s/^sha256sums=('.*/sha256sums=('${SUM256}'/" \
    PKGBUILD

# Reset pkgrel
sed -i \
    -e 's/pkgrel=.*/pkgrel=1/' \
    PKGBUILD

echo "$UPDATE_STATE"
