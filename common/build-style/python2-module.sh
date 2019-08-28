#
# This helper is for templates installing python2-only modules.
#

do_build() {
	if [ -n "$CROSS_BUILD" ]; then
		PYPREFIX="$PKGINST_CROSS_BASE"
		CFLAGS+=" -I${PKGINST_CROSS_BASE}/${py2_inc} -I${PKGINST_CROSS_BASE}/usr/include"
		LDFLAGS+=" -L${PKGINST_CROSS_BASE}/${py2_lib} -L${PKGINST_CROSS_BASE}/usr/lib"
		CC="${PKGINST_CROSS_TRIPLET}-gcc -pthread $CFLAGS $LDFLAGS"
		LDSHARED="${CC} -shared $LDFLAGS"
		env CC="$CC" LDSHARED="$LDSHARED" \
			PYPREFIX="$PYPREFIX" CFLAGS="$CFLAGS" \
			LDFLAGS="$LDFLAGS" python2 setup.py build ${make_build_args}
	else
		python2 setup.py build ${make_build_args}
	fi
}

do_install() {
	if [ -n "$CROSS_BUILD" ]; then
		PYPREFIX="$PKGINST_CROSS_BASE"
		CFLAGS+=" -I${PKGINST_CROSS_BASE}/${py2_inc} -I${PKGINST_CROSS_BASE}/usr/include"
		LDFLAGS+=" -L${PKGINST_CROSS_BASE}/${py2_lib} -L${PKGINST_CROSS_BASE}/usr/lib"
		CC="${PKGINST_CROSS_TRIPLET}-gcc -pthread $CFLAGS $LDFLAGS"
		LDSHARED="${CC} -shared $LDFLAGS"
		env CC="$CC" LDSHARED="$LDSHARED" \
			PYPREFIX="$PYPREFIX" CFLAGS="$CFLAGS" \
			LDFLAGS="$LDFLAGS" python2 setup.py \
				install --prefix=/usr --root=${DESTDIR} ${make_install_args}
	else
		python2 setup.py install --prefix=/usr --root=${DESTDIR} ${make_install_args}
	fi
}
