#!/bin/bash
#
# build.sh

if [ "$1" != "$2" ]; then
	arch="-a $2"
fi

# Tell pkginst-src what is our arch, this is done when doing
# binary-bootstrap, but we need to do it every time since
# our masterdir is ethereal.
# /bin/echo -e '\x1b[32mWriting bootstrap arch into .pkginst_chroot_init of masterdir\x1b[0m'
# echo "$1" > /hostrepo/masterdir/.pkginst_chroot_init

/bin/echo -e '\x1b[32mPreparing chroot with chroot_prepare()\x1b[0m'
source hostrepo/common/pkginst-src/shutils/chroot.sh || {
	echo "Failed to source chroot.sh for chroot_prepare()" >&2 ;
	exit 1
}

PKGINST_SRCPKGDIR=/hostrepo/srcpkgs PKGINST_MASTERDIR=/ chroot_prepare $1 || {
	echo "Failed to prepare chroot!" >&2 ;
	exit 1
}

# Two times due to updating pkginst itself
/hostrepo/pkginst-src -H "$HOME"/hostdir bootstrap-update
/hostrepo/pkginst-src -H "$HOME"/hostdir bootstrap-update

PKGS=$(/hostrepo/pkginst-src sort-dependencies $(cat /tmp/templates))

NPROCS=1
if [ -r /proc/cpuinfo ]; then
        NPROCS=$(grep ^proc /proc/cpuinfo|wc -l)
fi

for pkg in ${PKGS}; do
	/hostrepo/pkginst-src -j$NPROCS -H "$HOME"/hostdir $arch pkg "$pkg"
	[ $? -eq 1 ] && exit 1
done

exit 0
