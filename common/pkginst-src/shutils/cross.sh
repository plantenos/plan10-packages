# vim: set ts=4 sw=4 et:

remove_pkg_cross_deps() {
    local rval= tmplogf=
    [ -z "$PKGINST_CROSS_BUILD" ] && return 0

    cd $PKGINST_MASTERDIR || return 1
    msg_normal "${pkgver:-pkginst-src}: removing autocrossdeps, please wait...\n"
    tmplogf=$(mktemp) || exit 1

    if [ -z "$PKGINST_REMOVE_XCMD" ]; then
        source_file $PKGINST_CROSSPFDIR/${PKGINST_CROSS_BUILD}.sh
        PKGINST_REMOVE_XCMD="env PKGINST_TARGET_ARCH=$PKGINST_TARGET_MACHINE pkginst-remove -r /usr/$PKGINST_CROSS_TRIPLET"
    fi

    $PKGINST_REMOVE_XCMD -Ryo > $tmplogf 2>&1
    if [ $? -ne 0 ]; then
        msg_red "${pkgver:-pkginst-src}: failed to remove autocrossdeps:\n"
        cat $tmplogf && rm -f $tmplogf
        msg_error "${pkgver:-pkginst-src}: cannot continue!\n"
    fi
    rm -f $tmplogf
}

prepare_cross_sysroot() {
    local cross="$1"
    local statefile="$PKGINST_MASTERDIR/.pkginst-${cross}-done"

    [ -z "$cross" -o "$cross" = "" -o -f $statefile ] && return 0

    # Check for cross-vpkg-dummy available for the target arch, otherwise build it.
    pkg_available 'cross-vpkg-dummy>=0.31_1' $cross
    if [ $? -eq 0 ]; then
        $PKGINST_LIBEXECDIR/build.sh cross-vpkg-dummy cross-vpkg-dummy pkg $cross init || return $?
    fi

    check_installed_pkg cross-vpkg-dummy-0.30_1 $cross
    [ $? -eq 0 ] && return 0

    msg_normal "Installing $cross cross pkg: cross-vpkg-dummy ...\n"
    errlog=$(mktemp) || exit 1
    $PKGINST_INSTALL_XCMD -Syfd cross-vpkg-dummy &>$errlog
    rval=$?
    if [ $rval -ne 0 ]; then
        msg_red "failed to install cross-vpkg-dummy (error $rval)\n"
        cat $errlog
        rm -f $errlog
        msg_error "cannot continue due to errors above\n"
    fi
    rm -f $errlog
    # Create top level symlinks in sysroot.
    PKGINST_ARCH=$PKGINST_TARGET_MACHINE pkginst-reconfigure -r $PKGINST_CROSS_BASE -f base-files &>/dev/null
    # Create a sysroot/include and sysroot/lib symlink just in case.
    ln -s usr/include ${PKGINST_CROSS_BASE}/include
    ln -s usr/lib ${PKGINST_CROSS_BASE}/lib

    touch -f $statefile

    return 0
}

install_cross_pkg() {
    local cross="$1" rval errlog

    [ -z "$cross" -o "$cross" = "" ] && return 0

    # Check if the cross compiler pkg is available in repos, otherwise build it.
    pkg_available cross-${PKGINST_CROSS_TRIPLET}
    rval=$?
    if [ $rval -eq 0 ]; then
        $PKGINST_LIBEXECDIR/build.sh cross-${PKGINST_CROSS_TRIPLET} cross-${PKGINST_CROSS_TRIPLET} pkg || return $rval
    fi

    check_installed_pkg cross-${PKGINST_CROSS_TRIPLET}-0.1_1
    [ $? -eq 0 ] && return 0

    errlog=$(mktemp) || exit 1
    msg_normal "Installing $cross cross compiler: cross-${PKGINST_CROSS_TRIPLET} ...\n"
    $PKGINST_INSTALL_CMD -Syfd cross-${PKGINST_CROSS_TRIPLET} &>$errlog
    rval=$?
    if [ $rval -ne 0 -a $rval -ne 17 ]; then
        msg_red "failed to install cross-${PKGINST_CROSS_TRIPLET} (error $rval)\n"
        cat $errlog
        rm -f $errlog
        msg_error "cannot continue due to errors above\n"
    fi
    rm -f $errlog

    return 0
}

remove_cross_pkg() {
    local cross="$1" rval

    [ -z "$cross" -o "$cross" = "" ] && return 0

    source_file ${PKGINST_CROSSPFDIR}/${cross}.sh

    if [ -z "$CHROOT_READY" ]; then
        echo "ERROR: chroot mode not activated (install a bootstrap)."
        exit 1
    elif [ -z "$IN_CHROOT" ]; then
        return 0
    fi

    msg_normal "Removing cross pkg: cross-${PKGINST_CROSS_TRIPLET} ...\n"
    $PKGINST_REMOVE_CMD -Ry cross-${PKGINST_CROSS_TRIPLET} &>/dev/null
    rval=$?
    if [ $rval -ne 0 ]; then
        msg_error "failed to remove cross-${PKGINST_CROSS_TRIPLET} (error $rval)\n"
    fi
}
