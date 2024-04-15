# Maintainer: Nicolas Narvaez <nicomix1006@gmail.com>
# Contributor: EsauPR
# Contributor: bittin

pkgname=microsoft-edge-stable-bin
_pkgname=microsoft-edge
_pkgshortname=msedge
pkgver=123.0.2420.97
pkgrel=1
pkgdesc="A browser that combines a minimal design with sophisticated technology to make the web faster, safer, and easier"
arch=('x86_64')
url="https://www.microsoftedgeinsider.com/en-us/download"
license=('custom')
provides=('microsoft-edge-stable' 'edge-stable')
conflicts=('microsoft-edge-stable' 'edge-stable' 'edge-stable-bin' 'edge')
depends=('gtk3' 'libcups' 'nss' 'alsa-lib' 'libxtst' 'libdrm' 'mesa')
optdepends=(
	'pipewire: WebRTC desktop sharing under Wayland'
	'kdialog: for file dialogs in KDE'
	'gnome-keyring: for storing passwords in GNOME keyring'
	'kwallet: for storing passwords in KWallet'
	)
options=(!strip !zipman)
source=("https://packages.microsoft.com/repos/edge/pool/main/m/microsoft-edge-stable/${_pkgname}-stable_${pkgver}-1_amd64.deb"
        "microsoft-edge-stable.sh")
sha256sums=('abb3dc6e2d0942bff0bca22b82e783f5fd99eafd433280f66dc449286a83623b'
            'dc3765d2de6520b13f105b8001aa0e40291bc9457ac508160b23eea8811e26af')

package() {
	bsdtar -xf data.tar.xz -C "$pkgdir/"

	# suid sandbox
	chmod 4755 "${pkgdir}/opt/microsoft/${_pkgshortname}/msedge-sandbox"
	# install icons
	for res in 16 24 32 48 64 128 256; do
		install -Dm644 "${pkgdir}/opt/microsoft/${_pkgshortname}/product_logo_${res}.png" \
			"${pkgdir}/usr/share/icons/hicolor/${res}x${res}/apps/${_pkgname}.png"
	done
       # User flag aware launcher
       install -m755 microsoft-edge-stable.sh "${pkgdir}/usr/bin/microsoft-edge-stable"

	# License
	rm -r "${pkgdir}/etc/cron.daily/" "${pkgdir}/opt/microsoft/${_pkgshortname}/cron/"
	# Globbing seems not to work inside double parenthesis
	rm "${pkgdir}/opt/microsoft/${_pkgshortname}"/product_logo_*.png
	rm -r "$pkgdir"/usr/share/menu/
}
