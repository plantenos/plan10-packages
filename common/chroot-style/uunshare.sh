#!/bin/sh
#
# This chroot script uses pkginst-uunshare(8) with user_namespaces(7).
#
readonly MASTERDIR="$1"
readonly DISTDIR="$2"
readonly HOSTDIR="$3"
readonly EXTRA_ARGS="$4"
readonly CMD="$5"
shift 5

if ! command -v pkginst-uunshare >/dev/null 2>&1; then
	exit 1
fi

if [ -z "$MASTERDIR" -o -z "$DISTDIR" ]; then
	echo "$0 MASTERDIR/DISTDIR not set"
	exit 1
fi

exec pkginst-uunshare $EXTRA_ARGS -b $DISTDIR:/plan10-packages ${HOSTDIR:+-b $HOSTDIR:/host} -- $MASTERDIR $CMD $@
