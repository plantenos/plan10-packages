# vim: set ts=4 sw=4 et:

bulk_sortdeps() {
    local pkgs="$@"
    local pkg _pkg
    local NPROCS=$(($(nproc)*2))
    local NRUNNING=0

    tmpf=$(mktemp) || exit 1

    # Perform a topological sort of all *direct* build dependencies.
    for pkg in ${pkgs}; do
        if [ $NRUNNING -eq $NPROCS ]; then
            NRUNNING=0
            wait
        fi
        NRUNNING=$((NRUNNING+1))
        (
            for _pkg in $(./pkginst-src show-build-deps $pkg 2>/dev/null); do
                echo "$pkg $_pkg" >> $tmpf
            done
            echo "$pkg $pkg" >> $tmpf
        ) &
    done
    wait
    tsort $tmpf|tac
    rm -f $tmpf
}

bulk_build() {
    local sys="$1"
    local NPROCS=$(($(nproc)*2))
    local NRUNNING=0

    if [ "$PKGINST_CROSS_BUILD" ]; then
        source ${PKGINST_COMMONDIR}/cross-profiles/${PKGINST_CROSS_BUILD}.sh
        export PKGINST_ARCH=${PKGINST_TARGET_MACHINE}
    fi
    if ! command -v pkginst-checkvers &>/dev/null; then
        msg_error "pkginst-src: cannot find pkginst-checkvers(1) command!\n"
    fi

    # Compare installed pkg versions vs srcpkgs
    if [[ $sys ]]; then
        pkginst-checkvers -f '%n' -I -D $PKGINST_DISTDIR
        return $?
    fi
    # compare repo pkg versions vs srcpkgs
    for f in $(pkginst-checkvers -f '%n' -D $PKGINST_DISTDIR); do
        if [ $NRUNNING -eq $NPROCS ]; then
            NRUNNING=0
            wait
        fi
        NRUNNING=$((NRUNNING+1))
        (
            setup_pkg $f $PKGINST_TARGET_MACHINE &>/dev/null
            if show_avail &>/dev/null; then
                echo "$f"
            fi
        ) &
    done
    wait
    return $?
}

bulk_update() {
    local args="$1" pkgs f rval

    pkgs="$(bulk_build ${args})"
    [[ -z $pkgs ]] && return 0

    msg_normal "pkginst-src: the following packages must be rebuilt and updated:\n"
    for f in ${pkgs}; do
        echo " $f"
    done
    for f in ${pkgs}; do
        PKGINST_TARGET_PKG=$f
        read_pkg
        msg_normal "pkginst-src: building ${pkgver} ...\n"
        if [ -n "$CHROOT_READY" -a -z "$IN_CHROOT" ]; then
            chroot_handler pkg $PKGINST_TARGET_PKG
        else
            $PKGINST_LIBEXECDIR/build.sh $f $f pkg $PKGINST_CROSS_BUILD
        fi
        if [ $? -eq 1 ]; then
            msg_error "pkginst-src: failed to build $pkgver pkg!\n"
        fi
    done
    if [ -n "$pkgs" -a -n "$args" ]; then
        echo
        msg_normal "pkginst-src: updating your system, confirm to proceed...\n"
        ${PKGINST_SUCMD} "pkginst-install --repository=$PKGINST_REPOSITORY --repository=$PKGINST_REPOSITORY/nonfree -u ${pkgs}" || return 1
    fi
}
