#!/bin/bash
set -e

PKG_NAME="microsoft-edge-stable"
REPO_BASE="https://packages.microsoft.com/yumrepos/edge"

echo "Checking for updates..."

REPO_METADATA=$(curl -sSf "$REPO_BASE/repodata/repomd.xml" | \
    xmllint --xpath 'string(//*[local-name()="data"][@type="other"]/*[local-name()="location"]/@href)' -)

LATEST_VER=$(curl -sSf "$REPO_BASE/$REPO_METADATA" | \
    gzip -dc | \
    xmllint --xpath "string(//*[local-name()=\"package\"][@name=\"$PKG_NAME\"][last()]/*[local-name()=\"version\"]/@ver)" -)

if [ -z "$LATEST_VER" ]; then
    echo "Error: Failed to fetch version info."
    exit 1
fi

CURRENT_VER=$(grep "^pkgver=" PKGBUILD | cut -d'=' -f2)

echo "Remote: $LATEST_VER"
echo "Local:  $CURRENT_VER"

if [ "$LATEST_VER" == "$CURRENT_VER" ]; then
    echo "Already up to date."
    echo "UPDATE_NEEDED=false" >> "$GITHUB_OUTPUT"
else
    echo "New version found! Updating PKGBUILD..."

    sed -i "s/^pkgver=.*/pkgver=${LATEST_VER}/" PKGBUILD
    sed -i "s/^pkgrel=.*/pkgrel=1/" PKGBUILD

    NEW_SHA256=$(curl -sSf "$REPO_BASE/$REPO_METADATA" | \
        gzip -dc | \
        xmllint --xpath "string(//*[local-name()=\"package\"][@name=\"$PKG_NAME\"][last()]/@pkgid)" -)

    sed -i "s/^sha256sums=('.*/sha256sums=('${NEW_SHA256}'/" PKGBUILD

    echo "UPDATE_NEEDED=true" >> "$GITHUB_OUTPUT"
    echo "NEW_VERSION=${LATEST_VER}" >> "$GITHUB_OUTPUT"
fi
