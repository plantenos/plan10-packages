# This file sets up configure_args with common settings.

if [ -n "$build_style" -a "$build_style" != "gnu-configure" ]; then
	return 0
fi

export configure_args="--prefix=/usr --sysconfdir=/etc --sbindir=/usr/bin --bindir=/usr/bin
 --mandir=/usr/share/man --infodir=/usr/share/info --localstatedir=/var ${configure_args}"

. ${PKGINST_COMMONDIR}/build-profiles/${PKGINST_MACHINE}.sh
export configure_args+=" --host=$PKGINST_TRIPLET --build=$PKGINST_TRIPLET"

if [ "$PKGINST_TARGET_MACHINE" = "i686" ]; then
	# on x86 use /usr/lib32 as libdir, but just as fake directory,
	# because /usr/lib32 is a symlink to /usr/lib in plan10.
	export configure_args+=" --libdir=/usr/lib32"
fi

_AUTOCONFCACHEDIR=${PKGINST_COMMONDIR}/environment/configure/autoconf_cache

# From now on all vars are exported to the environment
set -a

# Read autoconf cache variables for native target.
case "$PKGINST_TARGET_MACHINE" in
	# musl libc
	*-musl) . ${_AUTOCONFCACHEDIR}/musl-linux
		;;
esac

# Cross compilation vars
if [ -z "$CROSS_BUILD" ]; then
	set +a
	return 0
fi

export configure_args+=" --host=$PKGINST_CROSS_TRIPLET --with-sysroot=$PKGINST_CROSS_BASE --with-libtool-sysroot=$PKGINST_CROSS_BASE "

# Read autoconf cache variables for cross target (taken from OE).
case "$PKGINST_TARGET_MACHINE" in
	# musl libc
	*-musl) . ${_AUTOCONFCACHEDIR}/common-linux
		. ${_AUTOCONFCACHEDIR}/musl-linux
		;;
	# gnu libc
	*)	. ${_AUTOCONFCACHEDIR}/common-linux
		. ${_AUTOCONFCACHEDIR}/common-glibc
		;;
esac

# Read apropiate autoconf cache files for target machine.
case "$PKGINST_TARGET_MACHINE" in
	armv5te*|armv?l*)
		. ${_AUTOCONFCACHEDIR}/endian-little
		. ${_AUTOCONFCACHEDIR}/arm-common
		. ${_AUTOCONFCACHEDIR}/arm-linux
		;;

	aarch64*)
		. ${_AUTOCONFCACHEDIR}/endian-little
		. ${_AUTOCONFCACHEDIR}/aarch64-linux
		;;

	i686*)	. ${_AUTOCONFCACHEDIR}/endian-little
		. ${_AUTOCONFCACHEDIR}/ix86-common
		;;

	mips)	. ${_AUTOCONFCACHEDIR}/endian-big
		. ${_AUTOCONFCACHEDIR}/mips-common
		. ${_AUTOCONFCACHEDIR}/mips-linux
		;;

	mipshf*)
		. ${_AUTOCONFCACHEDIR}/endian-big
		. ${_AUTOCONFCACHEDIR}/mips-common
		. ${_AUTOCONFCACHEDIR}/mips-linux
		;;

	mipsel*)
		. ${_AUTOCONFCACHEDIR}/endian-little
		. ${_AUTOCONFCACHEDIR}/mips-common
		. ${_AUTOCONFCACHEDIR}/mips-linux
		;;


	ppc|ppc-musl)
		. ${_AUTOCONFCACHEDIR}/endian-big
                . ${_AUTOCONFCACHEDIR}/ppc-common
                . ${_AUTOCONFCACHEDIR}/ppc-linux
		;;


	x86_64*)
		. ${_AUTOCONFCACHEDIR}/endian-little
		. ${_AUTOCONFCACHEDIR}/x86_64-linux
		;;

	ppc64le*)
		. ${_AUTOCONFCACHEDIR}/endian-little
		. ${_AUTOCONFCACHEDIR}/powerpc-common
		. ${_AUTOCONFCACHEDIR}/powerpc-linux
		. ${_AUTOCONFCACHEDIR}/powerpc64-linux
		;;

	ppc64*)
		. ${_AUTOCONFCACHEDIR}/endian-big
		. ${_AUTOCONFCACHEDIR}/powerpc-common
		. ${_AUTOCONFCACHEDIR}/powerpc-linux
		. ${_AUTOCONFCACHEDIR}/powerpc64-linux
		;;

	*) ;;
esac

unset _AUTOCONFCACHEDIR

set +a # vars are not exported to the environment anymore
