#!/bin/sh
#
# fetch-pkginstools.sh

mkdir -p /tmp/bin

/bin/echo -e '\x1b[32mInstalling pkginstools...\x1b[0m'
wget -q -O - https://github.com/plan10/pkginstools/archive/master.tar.gz | \
	gunzip | tar x -C /tmp/bin --wildcards "pkginstools-master/x*" \
	--strip-components=1 || exit 1
