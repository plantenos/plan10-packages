if [ -z "$CHROOT_READY" ]; then
	CFLAGS+=" -isystem ${PKGINST_MASTERDIR}/usr/include"
	LDFLAGS+=" -L${PKGINST_MASTERDIR}/usr/lib -Wl,-rpath-link=${PKGINST_MASTERDIR}/usr/lib"
fi
