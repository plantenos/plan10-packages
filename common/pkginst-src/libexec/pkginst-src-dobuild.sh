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

PKGINST_BUILD_DONE="${PKGINST_STATEDIR}/${sourcepkg}_${PKGINST_CROSS_BUILD}_build_done"

if [ -f $PKGINST_BUILD_DONE -a -z "$PKGINST_BUILD_FORCEMODE" ] ||
   [ -f $PKGINST_BUILD_DONE -a -n "$PKGINST_BUILD_FORCEMODE" -a $PKGINST_TARGET != "build" ]; then
    exit 0
fi

for f in $PKGINST_COMMONDIR/environment/build/*.sh; do
    source_file "$f"
done

run_step build optional

touch -f $PKGINST_BUILD_DONE

exit 0
