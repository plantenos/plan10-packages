#!/bin/sh
#
# pkginstlint.sh

[ "$PKGINSTLINT" ] || exit 0 

EXITCODE=0
for t in $(awk '{ print "srcpkgs/" $0 "/template" }' /tmp/templates); do
	/bin/echo -e "\x1b[32mLinting $t...\x1b[0m"
	pkginstlint "$t" || EXITCODE=$?
done
exit $EXITCODE
