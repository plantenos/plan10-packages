# This hook registers a PKGINST binary package into the specified local repository.

registerpkg() {
	local repo="$1" pkg="$2" arch="$3"

	if [ ! -f ${repo}/${pkg} ]; then
		msg_error "Unexistent binary package ${repo}/${pkg}!\n"
	fi

	printf "%s:%s:%s\n" "${arch}" "${repo}" "${pkg}" >> "${PKGINST_STATEDIR}/.${sourcepkg}_register_pkg"
}

hook() {
	local arch= binpkg= pkgdir=

	if [ "${archs// /}" = "noarch" ]; then
		arch=noarch
	elif [ -n "$PKGINST_TARGET_MACHINE" ]; then
		arch=$PKGINST_TARGET_MACHINE
	else
		arch=$PKGINST_MACHINE
	fi
	if [ "${archs// /}" != "noarch" -a -z "$PKGINST_CROSS_BUILD" -a -n "$PKGINST_ARCH" -a "$PKGINST_ARCH" != "$PKGINST_TARGET_MACHINE" ]; then
		arch=${PKGINST_ARCH}
	fi
	if [ -n "$repository" ]; then
		pkgdir=$PKGINST_REPOSITORY/$repository
	else
		pkgdir=$PKGINST_REPOSITORY
	fi
	binpkg=${pkgver}.${arch}.pkginst
	binpkg32=${pkgname}-32bit-${version}_${revision}.x86_64.pkginst
	binpkg_dbg=${pkgname}-dbg-${version}_${revision}.${arch}.pkginst

	# Register binpkg.
	if [ -f ${pkgdir}/${binpkg} ]; then
		registerpkg ${pkgdir} ${binpkg}
	fi

	# Register -dbg binpkg if it exists.
	pkgdir=$PKGINST_REPOSITORY/debug
	PKGDESTDIR="${PKGINST_DESTDIR}/${PKGINST_CROSS_TRIPLET}/${pkgname}-dbg-${version}"
	if [ -d ${PKGDESTDIR} -a -f ${pkgdir}/${binpkg_dbg} ]; then
		registerpkg ${pkgdir} ${binpkg_dbg}
	fi

	# Register 32bit binpkg if it exists.
	if [ "$PKGINST_TARGET_MACHINE" != "i686" ]; then
		return
	fi
	if [ -n "$repository" ]; then
		pkgdir=$PKGINST_REPOSITORY/multilib/$repository
	else
		pkgdir=$PKGINST_REPOSITORY/multilib
	fi
	PKGDESTDIR="${PKGINST_DESTDIR}/${pkgname}-32bit-${version}"
	if [ -d ${PKGDESTDIR} -a -f ${pkgdir}/${binpkg32} ]; then
		registerpkg ${pkgdir} ${binpkg32} x86_64
	fi
}
