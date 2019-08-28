# This hook creates wrappers for foo-config scripts in cross builds.
#
# Wrappers are created in ${wrksrc}/.pkginst/bin and this path is appended
# to make configure scripts find them.

generic_wrapper() {
	local wrapper="$1"
	[ ! -x ${PKGINST_CROSS_BASE}/usr/bin/${wrapper} ] && return 0
	[ -x ${PKGINST_WRAPPERDIR}/${wrapper} ] && return 0

	cat >>${PKGINST_WRAPPERDIR}/${wrapper}<<_EOF
#!/bin/sh
exec ${PKGINST_CROSS_BASE}/usr/bin/${wrapper} --prefix=${PKGINST_CROSS_BASE}/usr "\$@"
_EOF

	chmod 755 ${PKGINST_WRAPPERDIR}/${wrapper}
}

generic_wrapper2() {
	local wrapper="$1"

	[ ! -x ${PKGINST_CROSS_BASE}/usr/bin/${wrapper} ] && return 0
	[ -x ${PKGINST_WRAPPERDIR}/${wrapper} ] && return 0

	cat >>${PKGINST_WRAPPERDIR}/${wrapper}<<_EOF
#!/bin/sh
if [ "\$1" = "--prefix" ]; then
	echo "${PKGINST_CROSS_BASE}/usr"
elif [ "\$1" = "--cflags" ]; then
	${PKGINST_CROSS_BASE}/usr/bin/${wrapper} --cflags | sed -e "s,-I/usr/include,-I${PKGINST_CROSS_BASE}/usr/include,g"
elif [ "\$1" = "--libs" ]; then
	${PKGINST_CROSS_BASE}/usr/bin/${wrapper} --libs | sed -e "s,-L/usr/lib,-L${PKGINST_CROSS_BASE}/usr/lib,g"
else
	exec ${PKGINST_CROSS_BASE}/usr/bin/${wrapper} "\$@"
fi
exit \$?
_EOF
	chmod 755 ${PKGINST_WRAPPERDIR}/${wrapper}
}

generic_wrapper3() {
	local wrapper="$1"
	[ ! -x ${PKGINST_CROSS_BASE}/usr/bin/${wrapper} ] && return 0
	[ -x ${PKGINST_WRAPPERDIR}/${wrapper} ] && return 0

	cp ${PKGINST_CROSS_BASE}/usr/bin/${wrapper} ${PKGINST_WRAPPERDIR}
	sed -e "s,^libdir=.*,libdir=${PKGINST_CROSS_BASE}/usr/lib,g" -i ${PKGINST_WRAPPERDIR}/${wrapper}
	sed -e "s,^prefix=.*,prefix=${PKGINST_CROSS_BASE}/usr," -i ${PKGINST_WRAPPERDIR}/${wrapper}

	chmod 755 ${PKGINST_WRAPPERDIR}/${wrapper}
}

python_wrapper() {
	local wrapper="$1" version="$2"

	[ -x ${PKGINST_WRAPPERDIR}/${wrapper} ] && return 0
	cat >>${PKGINST_WRAPPERDIR}/${wrapper}<<_EOF
#!/bin/sh
if [ "\$1" = "--includes" ]; then
	echo "-I${PKGINST_CROSS_BASE}/usr/include/python${version}"
fi
exit \$?
_EOF
	chmod 755 ${PKGINST_WRAPPERDIR}/${wrapper}
}

pkgconfig_wrapper() {
	if [ ! -x /usr/bin/pkg-config ]; then
		return 0
	fi
	[ -x ${PKGINST_WRAPPERDIR}/${PKGINST_CROSS_TRIPLET}-pkg-config ] && return 0
	cat >>${PKGINST_WRAPPERDIR}/${PKGINST_CROSS_TRIPLET}-pkg-config<<_EOF
#!/bin/sh

export PKG_CONFIG_SYSROOT_DIR="$PKGINST_CROSS_BASE"
export PKG_CONFIG_PATH="$PKGINST_CROSS_BASE/usr/lib/pkgconfig:$PKGINST_CROSS_BASE/usr/share/pkgconfig\${PKG_CONFIG_PATH:+:\${PKG_CONFIG_PATH}}"
export PKG_CONFIG_LIBDIR="$PKGINST_CROSS_BASE/usr/lib/pkgconfig\${PKG_CONFIG_LIBDIR:+:\${PKG_CONFIG_LIBDIR}}"
exec /usr/bin/pkg-config "\$@"
_EOF
	chmod 755 ${PKGINST_WRAPPERDIR}/${PKGINST_CROSS_TRIPLET}-pkg-config
	ln -sf ${PKGINST_CROSS_TRIPLET}-pkg-config ${PKGINST_WRAPPERDIR}/pkg-config
}

vapigen_wrapper() {
	if [ ! -x /usr/bin/vapigen ]; then
		return 0
	fi
	[ -x ${PKGINST_WRAPPERDIR}/vapigen ] && return 0
	cat >>${PKGINST_WRAPPERDIR}/vapigen<<_EOF
#!/bin/sh
exec /usr/bin/vapigen \\
	 --vapidir=${PKGINST_CROSS_BASE}/usr/share/vala/vapi \\
	 --vapidir=${PKGINST_CROSS_BASE}/usr/share/vala-0.42/vapi \\
	 --girdir=${PKGINST_CROSS_BASE}/usr/share/gir-1.0 "\$@"
_EOF
	chmod 755 ${PKGINST_WRAPPERDIR}/vapigen
	ln -sf vapigen ${PKGINST_WRAPPERDIR}/vapigen-0.42
}

valac_wrapper() {
	if [ ! -x /usr/bin/valac ]; then
		return 0
	fi
	[ -x ${PKGINST_WRAPPERDIR}/valac ] && return 0
	cat >>${PKGINST_WRAPPERDIR}/valac<<_EOF
#!/bin/sh
exec /usr/bin/valac \\
	 --vapidir=${PKGINST_CROSS_BASE}/usr/share/vala/vapi \\
	 --vapidir=${PKGINST_CROSS_BASE}/usr/share/vala-0.42/vapi \\
	 --girdir=${PKGINST_CROSS_BASE}/usr/share/gir-1.0 "\$@"
_EOF
	chmod 755 ${PKGINST_WRAPPERDIR}/valac
	ln -sf valac ${PKGINST_WRAPPERDIR}/valac-0.42
}

install_wrappers() {
	local fname

	for f in ${PKGINST_COMMONDIR}/wrappers/*.sh; do
		fname=${f##*/}
		fname=${fname%.sh}
		install -m0755 ${f} ${PKGINST_WRAPPERDIR}/${fname}
	done
}

install_cross_wrappers() {
	local fname prefix

	if [ -n "$PKGINST_CCACHE" ]; then
		[ -x "/usr/bin/ccache" ] && prefix="/usr/bin/ccache "
	elif [ -n "$PKGINST_DISTCC" ]; then
		[ -x "/usr/bin/distcc" ] && prefix="/usr/bin/distcc "
	fi

	for fname in cc gcc; do
		sed -e "s,@BIN@,${prefix}/usr/bin/$PKGINST_CROSS_TRIPLET-gcc,g" \
			${PKGINST_COMMONDIR}/wrappers/cross-cc > \
			${PKGINST_WRAPPERDIR}/${PKGINST_CROSS_TRIPLET}-${fname}
		chmod 755 ${PKGINST_WRAPPERDIR}/${PKGINST_CROSS_TRIPLET}-${fname}
	done
	for fname in c++ g++; do
		sed -e "s,@BIN@,${prefix}/usr/bin/$PKGINST_CROSS_TRIPLET-g++,g" \
			${PKGINST_COMMONDIR}/wrappers/cross-cc > \
			${PKGINST_WRAPPERDIR}/${PKGINST_CROSS_TRIPLET}-${fname}
		chmod 755 ${PKGINST_WRAPPERDIR}/${PKGINST_CROSS_TRIPLET}-${fname}
	done
}

hook() {
	export PATH="$PKGINST_WRAPPERDIR:$PATH"

	install_wrappers

	[ -z "$CROSS_BUILD" ] && return 0

	install_cross_wrappers
	pkgconfig_wrapper
	vapigen_wrapper
	valac_wrapper
	generic_wrapper icu-config
	generic_wrapper libgcrypt-config
	generic_wrapper freetype-config
	generic_wrapper sdl-config
	generic_wrapper sdl2-config
	generic_wrapper gpgme-config
	generic_wrapper imlib2-config
	generic_wrapper libmikmod-config
	generic_wrapper pcre-config
	generic_wrapper net-snmp-config
	generic_wrapper wx-config
	generic_wrapper wx-config-3.0
	generic_wrapper wx-config-gtk3
	generic_wrapper2 curl-config
	generic_wrapper2 gpg-error-config
	generic_wrapper2 libassuan-config
	generic_wrapper2 mysql_config
	generic_wrapper2 taglib-config
	generic_wrapper2 nspr-config
	generic_wrapper2 gdal-config
	generic_wrapper3 libpng-config
	generic_wrapper3 xmlrpc-c-config
	generic_wrapper3 krb5-config
	generic_wrapper3 cups-config
	generic_wrapper3 Magick-config
	generic_wrapper3 fltk-config
	generic_wrapper3 xslt-config
	generic_wrapper3 xml2-config
	generic_wrapper3 fox-config
	generic_wrapper3 xapian-config
	generic_wrapper3 ncurses5-config
	generic_wrapper3 ncursesw5-config
	generic_wrapper3 libetpan-config
	generic_wrapper3 giblib-config
	python_wrapper python-config 2.7
	python_wrapper python3-config 3.6m
}
