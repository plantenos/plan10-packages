if [ -n "$CROSS_BUILD" ]; then
	CFLAGS+=" -I${PKGINST_CROSS_BASE}/usr/include"
	CXXFLAGS+=" -I${PKGINST_CROSS_BASE}/usr/include"
	LDFLAGS+=" -L${PKGINST_CROSS_BASE}/usr/lib"
fi
