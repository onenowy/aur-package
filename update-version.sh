#!/bin/bash
set -e

# 패키지 설정
PKG_NAME="microsoft-edge-stable"
REPO_BASE="https://packages.microsoft.com/yumrepos/edge"

echo "Checking for updates..."

# 1. 메타데이터 파일 위치 찾기 (repomd.xml 파싱)
REPO_METADATA=$(curl -sSf "$REPO_BASE/repodata/repomd.xml" | \
    xmllint --xpath 'string(//*[local-name()="data"][@type="other"]/*[local-name()="location"]/@href)' -)

# 2. 최신 버전 정보 파싱 (other.xml.gz 파싱)
LATEST_VER=$(curl -sSf "$REPO_BASE/$REPO_METADATA" | \
    gzip -dc | \
    xmllint --xpath "string(//*[local-name()=\"package\"][@name=\"$PKG_NAME\"][last()]/*[local-name()=\"version\"]/@ver)" -)

if [ -z "$LATEST_VER" ]; then
    echo "Error: Failed to fetch version info."
    exit 1
fi

# 3. 로컬 PKGBUILD 버전 확인
CURRENT_VER=$(grep "^pkgver=" PKGBUILD | cut -d'=' -f2)

echo "Remote: $LATEST_VER"
echo "Local:  $CURRENT_VER"

if [ "$LATEST_VER" == "$CURRENT_VER" ]; then
    echo "Already up to date."
    echo "UPDATE_NEEDED=false" >> "$GITHUB_OUTPUT"
else
    echo "New version found! Updating PKGBUILD..."

    # 버전 업데이트
    sed -i "s/^pkgver=.*/pkgver=${LATEST_VER}/" PKGBUILD
    # 릴리스 번호 초기화
    sed -i "s/^pkgrel=.*/pkgrel=1/" PKGBUILD

    # SHA256 체크섬 업데이트
    NEW_SHA256=$(curl -sSf "$REPO_BASE/$REPO_METADATA" | \
        gzip -dc | \
        xmllint --xpath "string(//*[local-name()=\"package\"][@name=\"$PKG_NAME\"][last()]/@pkgid)" -)

    sed -i "s/^sha256sums=('.*/sha256sums=('${NEW_SHA256}'/" PKGBUILD

    # GitHub Actions 변수 출력
    echo "UPDATE_NEEDED=true" >> "$GITHUB_OUTPUT"
    echo "NEW_VERSION=${LATEST_VER}" >> "$GITHUB_OUTPUT"
fi
