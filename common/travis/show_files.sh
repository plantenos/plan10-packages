#!/bin/sh
#
# show_files.sh

export PKGINST_TARGET_ARCH="$2" PKGINST_DISTDIR=/hostrepo

while read -r pkg; do
	for subpkg in $(xsubpkg $pkg); do
		/bin/echo -e "\x1b[32mFiles of $subpkg:\x1b[0m"
		pkginst-query --repository=$HOME/hostdir/binpkgs \
				   --repository=$HOME/hostdir/binpkgs/nonfree \
				   -f "$subpkg"
	done
done < /tmp/templates
