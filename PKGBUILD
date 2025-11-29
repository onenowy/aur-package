# Maintainer: Nicolas Narvaez <nicomix1006@gmail.com>
# Contributor: EsauPR
# Contributor: bittin

pkgname=microsoft-edge-stable
_pkgname=microsoft-edge
_pkgshortname=msedge
pkgver=142.0.3595.94
pkgrel=1
pkgdesc="A browser that combines a minimal design with sophisticated technology to make the web faster, safer, and easier"
arch=('x86_64')
url="https://www.microsoftedgeinsider.com/en-us/download"
license=('custom')
depends=('gtk3' 'nss' 'alsa-lib' 'xdg-utils' 'libxss' 'libcups' 'libgcrypt'
         'ttf-liberation' 'systemd' 'dbus' 'libpulse' 'pciutils' 'libva'
         'libffi' 'desktop-file-utils' 'hicolor-icon-theme')
optdepends=('pipewire: WebRTC desktop sharing under Wayland'
            'kdialog: support for native dialogs in Plasma'
            'gtk4: for --gtk-version=4 (GTK4 IME might work better on Wayland)'
            'org.freedesktop.secrets: password storage backend on GNOME / Xfce'
            'kwallet: support for storing passwords in KWallet on Plasma'
            'upower: Battery Status API support')
options=(!strip !zipman)
source=("https://packages.microsoft.com/yumrepos/edge/Packages/m/${_pkgname}-stable-${pkgver}-1.x86_64.rpm"
        "microsoft-edge-stable.sh")
sha256sums=('46c5f918c982805a2d2d748dbef2f0d539ebf067669d1cf7dce4249f8a1536c9'
            'dc3765d2de6520b13f105b8001aa0e40291bc9457ac508160b23eea8811e26af')

package() {

	cp --parents -a {opt,usr} "$pkgdir"
	# suid sandbox
	chmod 4755 "${pkgdir}/opt/microsoft/${_pkgshortname}/msedge-sandbox"
	# install icons
	for res in 16 24 32 48 64 128 256; do
		install -Dm644 "${pkgdir}/opt/microsoft/${_pkgshortname}/product_logo_${res}.png" \
			"${pkgdir}/usr/share/icons/hicolor/${res}x${res}/apps/${_pkgname}.png"
	done
       # User flag aware launcher
       install -m755 microsoft-edge-stable.sh "${pkgdir}/usr/bin/microsoft-edge-stable"

       rm "${pkgdir}/opt/microsoft/${_pkgshortname}"/product_logo_*.png
}
