#!/bin/bash
#
# vim: set ts=4 sw=4 et:
#
# Passed arguments:
#	$1 - pkgname [REQUIRED]
#   $2 - subpkg mode [REQUIRED]
#	$2 - cross target [OPTIONAL]

if [ $# -lt 2 -o $# -gt 3 ]; then
    echo "${0##*/}: invalid number of arguments: pkgname subpkg-mode [cross-target]"
    exit 1
fi

PKGNAME="$1"
SUBPKG_MODE="$2"
PKGINST_CROSS_BUILD="$3"

for f in $PKGINST_SHUTILSDIR/*.sh; do
    . $f
done

setup_pkg "$PKGNAME" $PKGINST_CROSS_BUILD

for f in $PKGINST_COMMONDIR/environment/install/*.sh; do
    source_file "$f"
done

PKGINST_INSTALL_DONE="${PKGINST_STATEDIR}/${sourcepkg}_${PKGINST_CROSS_BUILD}_install_done"

ch_wrksrc

if [ "$SUBPKG_MODE"  = "no" ]; then
    if [ ! -f $PKGINST_INSTALL_DONE ] || [ -f $PKGINST_INSTALL_DONE -a -n "$PKGINST_BUILD_FORCEMODE" ]; then
        mkdir -p $PKGINST_DESTDIR/$PKGINST_CROSS_TRIPLET/$pkgname-$version

        run_step install "" skip

        touch -f $PKGINST_INSTALL_DONE
    fi
    exit 0
fi

PKGINST_SUBPKG_INSTALL_DONE="${PKGINST_STATEDIR}/${PKGNAME}_${PKGINST_CROSS_BUILD}_subpkg_install_done"

# If it's a subpkg execute the pkg_install() function.
if [ ! -f $PKGINST_SUBPKG_INSTALL_DONE ]; then
    if [ "$sourcepkg" != "$PKGNAME" ]; then
        # Source all subpkg environment setup snippets.
        for f in ${PKGINST_COMMONDIR}/environment/setup-subpkg/*.sh; do
            source_file "$f"
        done

        ${PKGNAME}_package
        pkgname=$PKGNAME

        source_file $PKGINST_COMMONDIR/environment/build-style/${build_style}.sh

        install -d $PKGDESTDIR
        if declare -f pkg_install >/dev/null; then
            export PKGINST_PKGDESTDIR=1
            run_pkg_hooks pre-install
            run_func pkg_install
        fi
    fi
    setup_pkg_depends ${pkgname:=$PKGNAME} || exit 1
    run_pkg_hooks post-install
    touch -f $PKGINST_SUBPKG_INSTALL_DONE
fi

exit 0
