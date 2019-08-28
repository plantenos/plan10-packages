#!/bin/bash
#
# vim: set ts=4 sw=4 et:
#
# Passed arguments:
# 	$1 - pkgname [REQUIRED]
#	$2 - path to local repository [REQUIRED]
# 	$3 - cross-target [OPTIONAL]

if [ $# -lt 2 -o $# -gt 3 ]; then
    echo "${0##*/}: invalid number of arguments: pkgname repository [cross-target]"
    exit 1
fi

PKGNAME="$1"
PKGINST_REPOSITORY="$2"
PKGINST_CROSS_BUILD="$3"

for f in $PKGINST_SHUTILSDIR/*.sh; do
    . $f
done

setup_pkg "$PKGNAME" $PKGINST_CROSS_BUILD

for f in $PKGINST_COMMONDIR/environment/pkg/*.sh; do
    source_file "$f"
done

if [ "$sourcepkg" != "$PKGNAME" ]; then
    # Source all subpkg environment setup snippets.
    for f in ${PKGINST_COMMONDIR}/environment/setup-subpkg/*.sh; do
        source_file "$f"
    done

    ${PKGNAME}_package
    pkgname=$PKGNAME
fi

if [ -s $PKGINST_MASTERDIR/.pkginst_chroot_init ]; then
    export PKGINST_ARCH=$(<$PKGINST_MASTERDIR/.pkginst_chroot_init)
fi

# Run do-pkg hooks.
run_pkg_hooks "do-pkg"

# Run post-pkg hooks.
run_pkg_hooks post-pkg

exit 0
