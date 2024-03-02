#!/bin/sh
CURRENT_VER=$(awk '/pkgver=/' current-PKGBUILD | cut -d '=' -f 2)
CURRENT_REL=$(awk '/pkgrel=/' current-PKGBUILD | cut -d '=' -f 2)

git clone https://gitlab.archlinux.org/archlinux/packaging/packages/linux.git

cd linux

NEW_VER=$(awk '/pkgver=/' PKGBUILD | cut -d '=' -f 2)
NEW_REL=$(awk '/pkgrel=/' PKGBUILD | cut -d '=' -f 2)

UPDATE_STATE="false"

if [ "$CURRENT_VER" != "$NEW_VER" -o  "$CURRENT_REL" != "$NEW_REL" ];then
	UPDATE_STATE="${NEW_VER}-${NEW_REL}"
	patch -p1 < modify-pkgbuild.patch
	sed -i "s/pkgbase=linux/pkgbase=linux-predator/g" PKGBUILD
	sed -i "s/pkgdesc='Linux'/pkgdesc='Linux for acer predator'/g" PKGBUILD
fi

echo $UPDATE_STATE