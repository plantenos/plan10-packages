#!/bin/bash
#
# vim: set ts=4 sw=4 et:
#
# Passed arguments:
#	$1 - pkgname to build [REQUIRED]
#	$2 - cross target [OPTIONAL]

if [ $# -lt 1 -o $# -gt 2 ]; then
    echo "${0##*/}: invalid number of arguments: pkgname [cross-target]"
    exit 1
fi

PKGNAME="$1"
PKGINST_CROSS_BUILD="$2"

for f in $PKGINST_SHUTILSDIR/*.sh; do
    . $f
done

setup_pkg "$PKGNAME" $PKGINST_CROSS_BUILD

PKGINST_CHECK_DONE="${PKGINST_STATEDIR}/${sourcepkg}_${PKGINST_CROSS_BUILD}_check_done"

if [ -n "$PKGINST_CROSS_BUILD" ]; then
    msg_normal "${pkgname}-${version}_${revision}: skipping check (cross build for $PKGINST_CROSS_BUILD) ...\n"
    exit 0
fi

if [ -z "$PKGINST_CHECK_PKGS" ]; then
    msg_normal "${pkgname}-${version}_${revision}: skipping check (PKGINST_CHECK_PKGS is disabled) ...\n"
    exit 0
fi

for f in $PKGINST_COMMONDIR/environment/check/*.sh; do
    source_file "$f"
done

run_step check optional

touch -f $PKGINST_CHECK_DONE

exit 0
