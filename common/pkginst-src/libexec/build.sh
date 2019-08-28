#!/bin/bash
#
# vim: set ts=4 sw=4 et:
#
# Passed arguments:
#   $1 - current pkgname to build [REQUIRED]
#   $2 - target pkgname (origin) to build [REQUIRED]
#   $3 - pkginst target [REQUIRED]
#   $4 - cross target [OPTIONAL]
#   $5 - internal [OPTIONAL]

if [ $# -lt 3 -o $# -gt 5 ]; then
    echo "${0##*/}: invalid number of arguments: pkgname targetpkg target [cross-target]"
    exit 1
fi

readonly PKGNAME="$1"
readonly PKGINST_TARGET_PKG="$2"
readonly PKGINST_TARGET="$3"
readonly PKGINST_CROSS_BUILD="$4"
readonly PKGINST_CROSS_PREPARE="$5"

export PKGINST_TARGET

for f in $PKGINST_SHUTILSDIR/*.sh; do
    . $f
done

setup_pkg "$PKGNAME" $PKGINST_CROSS_BUILD
readonly SOURCEPKG="$sourcepkg"

show_pkg_build_options
check_pkg_arch $PKGINST_CROSS_BUILD

if [ -z "$PKGINST_CROSS_PREPARE" ]; then
    prepare_cross_sysroot $PKGINST_CROSS_BUILD || exit $?
fi
if [ -z "$PKGINST_DEPENDENCY" -a -z "$PKGINST_TEMP_MASTERDIR" -a -n "$PKGINST_KEEP_ALL" -a "$PKGINST_CHROOT_CMD" = "proot" ]; then
    remove_pkg_autodeps
fi
# Install dependencies from binary packages
if [ "$PKGNAME" != "$PKGINST_TARGET_PKG" -o -z "$PKGINST_SKIP_DEPS" ]; then
    install_pkg_deps $PKGNAME $PKGINST_TARGET_PKG pkg $PKGINST_CROSS_BUILD $PKGINST_CROSS_PREPARE || exit $?
fi

if [ "$PKGINST_CROSS_BUILD" ]; then
    install_cross_pkg $PKGINST_CROSS_BUILD || exit $?
fi

# Fetch distfiles after installing required dependencies,
# because some of them might be required for do_fetch().
$PKGINST_LIBEXECDIR/pkginst-src-dofetch.sh $SOURCEPKG $PKGINST_CROSS_BUILD || exit 1
[ "$PKGINST_TARGET" = "fetch" ] && exit 0

# Fetch, extract, build and install into the destination directory.
$PKGINST_LIBEXECDIR/pkginst-src-doextract.sh $SOURCEPKG $PKGINST_CROSS_BUILD || exit 1
[ "$PKGINST_TARGET" = "extract" ] && exit 0

# Run patch phrase
$PKGINST_LIBEXECDIR/pkginst-src-dopatch.sh $SOURCEPKG $PKGINST_CROSS_BUILD || exit 1
[ "$PKGINST_TARGET" = "patch" ] && exit 0

# Run configure phase
$PKGINST_LIBEXECDIR/pkginst-src-doconfigure.sh $SOURCEPKG $PKGINST_CROSS_BUILD || exit 1
[ "$PKGINST_TARGET" = "configure" ] && exit 0

# Run build phase
$PKGINST_LIBEXECDIR/pkginst-src-dobuild.sh $SOURCEPKG $PKGINST_CROSS_BUILD || exit 1
[ "$PKGINST_TARGET" = "build" ] && exit 0

# Run check phase
$PKGINST_LIBEXECDIR/pkginst-src-docheck.sh $SOURCEPKG $PKGINST_CROSS_BUILD || exit 1
[ "$PKGINST_TARGET" = "check" ] && exit 0

# Install pkgs into destdir.
$PKGINST_LIBEXECDIR/pkginst-src-doinstall.sh $SOURCEPKG no $PKGINST_CROSS_BUILD || exit 1

for subpkg in ${subpackages} ${sourcepkg}; do
    $PKGINST_LIBEXECDIR/pkginst-src-doinstall.sh $subpkg yes $PKGINST_CROSS_BUILD || exit 1
done
for subpkg in ${subpackages} ${sourcepkg}; do
    $PKGINST_LIBEXECDIR/pkginst-src-prepkg.sh $subpkg $PKGINST_CROSS_BUILD || exit 1
done

for subpkg in ${subpackages} ${sourcepkg}; do
    if [ "$PKGNAME" = "${subpkg}" -a "$PKGINST_TARGET" = "install" ]; then
        exit 0
    fi
done

# Clean list of preregistered packages
printf "" > ${PKGINST_STATEDIR}/.${sourcepkg}_register_pkg
# If install went ok generate the binpkgs.
for subpkg in ${subpackages} ${sourcepkg}; do
    $PKGINST_LIBEXECDIR/pkginst-src-dopkg.sh $subpkg "$PKGINST_REPOSITORY" "$PKGINST_CROSS_BUILD" || exit 1
done

# Registering packages at once per repository. This makes sure that staging is
# triggered for all new packages if any of them introduces inconsistencies.
cut -d: -f 1,2 ${PKGINST_STATEDIR}/.${sourcepkg}_register_pkg | sort -u | \
    while IFS=: read -r arch repo; do
        paths=$(grep "^$arch:$repo:" "${PKGINST_STATEDIR}/.${sourcepkg}_register_pkg" | \
            cut -d : -f 2,3 | tr ':' '/')
        if [ -n "${arch}" ]; then
            msg_normal "Registering new packages to $repo ($arch)\n"
            PKGINST_TARGET_ARCH=${arch} $PKGINST_RINDEX_CMD \
                ${PKGINST_REPO_COMPTYPE:+--compression $PKGINST_REPO_COMPTYPE} ${PKGINST_BUILD_FORCEMODE:+-f} -a ${paths}
        else
            msg_normal "Registering new packages to $repo\n"
            if [ -n "$PKGINST_CROSS_BUILD" ]; then
                $PKGINST_RINDEX_XCMD ${PKGINST_REPO_COMPTYPE:+--compression $PKGINST_REPO_COMPTYPE} \
					${PKGINST_BUILD_FORCEMODE:+-f} -a ${paths}
            else
                $PKGINST_RINDEX_CMD ${PKGINST_REPO_COMPTYPE:+--compression $PKGINST_REPO_COMPTYPE} \
					${PKGINST_BUILD_FORCEMODE:+-f} -a ${paths}
            fi
        fi
    done

# pkg cleanup
if declare -f do_clean >/dev/null; then
    run_func do_clean
fi

if [ -n "$PKGINST_DEPENDENCY" -o -z "$PKGINST_KEEP_ALL" ]; then
    remove_pkg_autodeps
    remove_pkg_wrksrc
    remove_pkg $PKGINST_CROSS_BUILD
    remove_pkg_statedir
fi

# If base-chroot not installed, install "base-files" into masterdir
# from local repository; this is the only pkg required to be able to build
# the bootstrap pkgs from scratch.
if [ -z "$CHROOT_READY" -a "$PKGNAME" = "base-files" ]; then
    msg_normal "Installing $PKGNAME into masterdir...\n"
    _log=$(mktemp) || exit 1
    PKGINST_ARCH=$PKGINST_MACHINE $PKGINST_INSTALL_CMD -yf $PKGNAME >${_log} 2>&1
    if [ $? -ne 0 ]; then
        msg_red "Failed to install $PKGNAME into masterdir, see below for errors:\n"
        cat ${_log}
        rm -f ${_log}
        msg_error "Cannot continue!\n"
    fi
    rm -f ${_log}
fi

exit 0
