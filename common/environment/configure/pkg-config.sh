# This snippet setups pkg-config vars.

if [ -z "$CHROOT_READY" ]; then
	export PKG_CONFIG_PATH="${PKGINST_MASTERDIR}/usr/lib/pkgconfig:${PKGINST_MASTERDIR}/usr/share/pkgconfig"
fi
