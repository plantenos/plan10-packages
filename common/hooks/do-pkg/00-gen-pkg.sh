# This hook generates a PKGINST binary package from an installed package in destdir.

genpkg() {
	local pkgdir="$1" arch="$2" desc="$3" pkgver="$4" binpkg="$5"
	local _preserve _deps _shprovides _shrequires _gitrevs _provides _conflicts
	local _replaces _reverts _mutable_files _conf_files f

	if [ ! -d "${PKGDESTDIR}" ]; then
		msg_warn "$pkgver: cannot find pkg destdir... skipping!\n"
		return 0
	fi

	[ ! -d $pkgdir ] && mkdir -p $pkgdir

	while [ -f $pkgdir/${binpkg}.lock ]; do
		msg_warn "${pkgver}: binpkg is being created, waiting for 1s...\n"
		sleep 1
	done

	# Don't overwrite existing binpkgs by default, skip them.
	if [ -f $pkgdir/$binpkg -a -z "$PKGINST_BUILD_FORCEMODE" ]; then
		msg_normal "${pkgver}: skipping existing $binpkg pkg...\n"
		return 0
	fi

	touch -f $pkgdir/${binpkg}.lock

	if [ ! -d $pkgdir ]; then
		mkdir -p $pkgdir
	fi
	cd $pkgdir

	_preserve=${preserve:+-p}
	if [ -s ${PKGDESTDIR}/rdeps ]; then
		_deps="$(<${PKGDESTDIR}/rdeps)"
	fi
	if [ -s ${PKGDESTDIR}/shlib-provides ]; then
		_shprovides="$(<${PKGDESTDIR}/shlib-provides)"
	fi
	if [ -s ${PKGDESTDIR}/shlib-requires ]; then
		_shrequires="$(<${PKGDESTDIR}/shlib-requires)"
	fi
	if [ -s ${PKGINST_STATEDIR}/gitrev ]; then
		_gitrevs="$(<${PKGINST_STATEDIR}/gitrev)"
	fi

	# Stripping whitespaces
	local _provides="$(echo $provides)"
	local _conflicts="$(echo $conflicts)"
	local _replaces="$(echo $replaces)"
	local _reverts="$(echo $reverts)"
	local _mutable_files="$(echo $mutable_files)"
	local _conf_files="$(expand_destdir "$conf_files")"
	local _alternatives="$(echo $alternatives)"
	local _tags="$(echo $tags)"
	local _changelog="$(echo $changelog)"

	msg_normal "Creating $binpkg for repository $pkgdir ...\n"

	#
	# Create the PKGINST binary package.
	#
	pkginst-create \
		${_provides:+--provides "${_provides}"} \
		${_conflicts:+--conflicts "${_conflicts}"} \
		${_replaces:+--replaces "${_replaces}"} \
		${_reverts:+--reverts "${_reverts}"} \
		${_mutable_files:+--mutable-files "${_mutable_files}"} \
		${_deps:+--dependencies "${_deps}"} \
		${_conf_files:+--config-files "${_conf_files}"} \
		${PKG_BUILD_OPTIONS:+--build-options "${PKG_BUILD_OPTIONS}"} \
		${_gitrevs:+--source-revisions "${_gitrevs}"} \
		${_shprovides:+--shlib-provides "${_shprovides}"} \
		${_shrequires:+--shlib-requires "${_shrequires}"} \
		${_alternatives:+--alternatives "${_alternatives}"} \
		${_preserve:+--preserve} \
		${tags:+--tags "${tags}"} \
		${_changelog:+--changelog "${_changelog}"} \
		--architecture ${arch} \
		--homepage "${homepage}" \
		--license "${license}" \
		--maintainer "${maintainer}" \
		--desc "${desc}" \
		--pkgver "${pkgver}" \
		--compression ${PKGINST_PKG_COMPTYPE:=xz} \
		--quiet \
		${PKGDESTDIR}
	rval=$?

	rm -f $pkgdir/${binpkg}.lock

	if [ $rval -ne 0 ]; then
		rm -f $pkgdir/$binpkg
		msg_error "Failed to created binary package: $binpkg!\n"
	fi
}

hook() {
	local arch= binpkg= repo= _pkgver= _desc= _pkgn= _pkgv= _provides= \
		_replaces= _reverts= f= found_dbg_subpkg=

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

	binpkg=${pkgver}.${arch}.pkginst

	if [ -n "$repository" ]; then
		repo=$PKGINST_REPOSITORY/$repository
	else
		repo=$PKGINST_REPOSITORY
	fi

	genpkg ${repo} ${arch} "${short_desc}" ${pkgver} ${binpkg}

	for f in ${provides}; do
		_pkgn="$($PKGINST_UHELPER_CMD getpkgname $f)"
		_pkgv="$($PKGINST_UHELPER_CMD getpkgversion $f)"
		_provides+=" ${_pkgn}-32bit-${_pkgv}"
	done
	for f in ${replaces}; do
		_pkgn="$($PKGINST_UHELPER_CMD getpkgdepname $f)"
		_pkgv="$($PKGINST_UHELPER_CMD getpkgdepversion $f)"
		_replaces+=" ${_pkgn}-32bit${_pkgv}"
	done

	# Generate -dbg pkg.
	for f in ${subpackages}; do
		# If there's an explicit subpkg named ${pkgname}-dbg, don't generate
		# it automagically (required by linuxX.X).
		if [ "${sourcepkg}-dbg" = "$f" ]; then
			found_dbg_subpkg=1
			break
		fi
	done
	if [ -z "$found_dbg_subpkg" -a -d "${PKGINST_DESTDIR}/${PKGINST_CROSS_TRIPLET}/${pkgname}-dbg-${version}" ]; then
		source ${PKGINST_COMMONDIR}/environment/setup-subpkg/subpkg.sh
		repo=$PKGINST_REPOSITORY/debug
		_pkgver=${pkgname}-dbg-${version}_${revision}
		_desc="${short_desc} (debug files)"
		binpkg=${_pkgver}.${arch}.pkginst
		PKGDESTDIR="${PKGINST_DESTDIR}/${PKGINST_CROSS_TRIPLET}/${pkgname}-dbg-${version}"
		genpkg ${repo} ${arch} "${_desc}" ${_pkgver} ${binpkg}
	fi
	# Generate 32bit pkg.
	if [ "$PKGINST_TARGET_MACHINE" != "i686" ]; then
		return
	fi
	if [ -d "${PKGINST_DESTDIR}/${pkgname}-32bit-${version}" ]; then
		source ${PKGINST_COMMONDIR}/environment/setup-subpkg/subpkg.sh
		if [ -n "$repository" ]; then
			repo=$PKGINST_REPOSITORY/multilib/$repository
		else
			repo=$PKGINST_REPOSITORY/multilib
		fi
		_pkgver=${pkgname}-32bit-${version}_${revision}
		_desc="${short_desc} (32bit)"
		binpkg=${_pkgver}.x86_64.pkginst
		PKGDESTDIR="${PKGINST_DESTDIR}/${pkgname}-32bit-${version}"
		[ -n "${_provides}" ] && export provides="${_provides}"
		[ -n "${_replaces}" ] && export replaces="${_replaces}"
		genpkg ${repo} x86_64 "${_desc}" ${_pkgver} ${binpkg}
	fi
}
