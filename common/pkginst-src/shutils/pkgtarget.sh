# vim: set ts=4 sw=4 et:

check_pkg_arch() {
    local cross="$1" _arch f match nonegation

    if [ -n "$archs" -a "${archs// /}" != "noarch" ]; then
        if [ -n "$cross" ]; then
            _arch="$PKGINST_TARGET_MACHINE"
        elif [ -n "$PKGINST_ARCH" ]; then
            _arch="$PKGINST_ARCH"
        else
            _arch="$PKGINST_MACHINE"
        fi
        set -f
        for f in ${archs}; do
            set +f
            nonegation=${f##\~*}
            f=${f#\~}
            case "${_arch}" in
                $f) match=1; break ;;
            esac
        done
        if [ -z "$nonegation" -a -n "$match" ] || [ -n "$nonegation" -a -z "$match" ]; then
            msg_red "$pkgname: this package cannot be built for ${_arch}.\n"
            exit 2
        fi
    fi
}

# Returns 1 if pkg is available in pkginst repositories, 0 otherwise.
pkg_available() {
    local pkg="$1" cross="$2" pkgver

    if [ -n "$cross" ]; then
        pkgver=$($PKGINST_QUERY_XCMD -R -ppkgver "${pkg}" 2>/dev/null)
    else
        pkgver=$($PKGINST_QUERY_CMD -R -ppkgver "${pkg}" 2>/dev/null)
    fi

    if [ -z "$pkgver" ]; then
        return 0
    fi
    return 1
}

remove_pkg_autodeps() {
    local rval= tmplogf=

    cd $PKGINST_MASTERDIR || return 1
    msg_normal "${pkgver:-pkginst-src}: removing autodeps, please wait...\n"
    tmplogf=$(mktemp) || exit 1

    remove_pkg_cross_deps
    $PKGINST_RECONFIGURE_CMD -a >> $tmplogf 2>&1
    echo yes | $PKGINST_REMOVE_CMD -Ryod >> $tmplogf 2>&1
    rval=$?
    if [ $rval -eq 0 ]; then
        echo yes | $PKGINST_REMOVE_CMD -Ryod >> $tmplogf 2>&1
        rval=$?
    fi

    if [ $rval -ne 0 ]; then
        msg_red "${pkgver:-pkginst-src}: failed to remove autodeps: (returned $rval)\n"
        cat $tmplogf && rm -f $tmplogf
        msg_error "${pkgver:-pkginst-src}: cannot continue!\n"
    fi
    rm -f $tmplogf
}

remove_pkg_wrksrc() {
    if [ -d "$wrksrc" ]; then
        msg_normal "$pkgver: cleaning build directory...\n"
        chmod -R +wX $wrksrc # Needed to delete Go Modules
        rm -rf $wrksrc
    fi
}

remove_pkg_statedir() {
    if [ -d "$PKGINST_STATEDIR" ]; then
        rm -rf "$PKGINST_STATEDIR"
    fi
}

remove_pkg() {
    local cross="$1" _destdir f

    [ -z $pkgname ] && msg_error "unexistent package, aborting.\n"

    if [ -n "$cross" ]; then
        _destdir="$PKGINST_DESTDIR/$PKGINST_CROSS_TRIPLET"
    else
        _destdir="$PKGINST_DESTDIR"
    fi

    [ ! -d ${_destdir} ] && return

    for f in ${sourcepkg} ${subpackages}; do
        if [ -d "${_destdir}/${f}-${version}" ]; then
            msg_normal "$f: removing files from destdir...\n"
            rm -rf ${_destdir}/${f}-${version}
        fi
        if [ -d "${_destdir}/${f}-dbg-${version}" ]; then
            msg_normal "$f: removing dbg files from destdir...\n"
            rm -rf ${_destdir}/${f}-dbg-${version}
        fi
        if [ -d "${_destdir}/${f}-32bit-${version}" ]; then
            msg_normal "$f: removing 32bit files from destdir...\n"
            rm -rf ${_destdir}/${f}-32bit-${version}
        fi
        rm -f ${PKGINST_STATEDIR}/${f}_${cross}_subpkg_install_done
        rm -f ${PKGINST_STATEDIR}/${f}_${cross}_prepkg_done
    done
    rm -f ${PKGINST_STATEDIR}/${sourcepkg}_${cross}_install_done
    rm -f ${PKGINST_STATEDIR}/${sourcepkg}_${cross}_pre_install_done
    rm -f ${PKGINST_STATEDIR}/${sourcepkg}_${cross}_post_install_done
}
