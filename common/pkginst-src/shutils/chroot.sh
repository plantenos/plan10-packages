# vim: set ts=4 sw=4 et:

# FIXME: $PKGINST_FFLAGS is not set when chroot_init() is run
# It is set in common/build-profiles/bootstrap.sh but lost somewhere?
chroot_init() {
    mkdir -p $PKGINST_MASTERDIR/etc/pkginst

    cat > $PKGINST_MASTERDIR/etc/pkginst/pkginst-src.conf <<_EOF
# Generated configuration file by pkginst-src, DO NOT EDIT!
$(grep -E '^PKGINST_.*' "$PKGINST_CONFIG_FILE")
PKGINST_MASTERDIR=/
PKGINST_CFLAGS="$PKGINST_CFLAGS"
PKGINST_CXXFLAGS="$PKGINST_CXXFLAGS"
PKGINST_FFLAGS="-fPIC -pipe"
PKGINST_CPPFLAGS="$PKGINST_CPPFLAGS"
PKGINST_LDFLAGS="$PKGINST_LDFLAGS"
PKGINST_HOSTDIR=/host
# End of configuration file.
_EOF

    # Create custom script to start the chroot bash shell.
    cat > $PKGINST_MASTERDIR/bin/pkginst-shell <<_EOF
#!/bin/sh

PKGINST_SRC_VERSION="$PKGINST_SRC_VERSION"

. /etc/pkginst/pkginst-src.conf

PATH=/plan10-packages:/usr/bin

exec env -i -- SHELL=/bin/sh PATH="\$PATH" DISTCC_HOSTS="\$PKGINST_DISTCC_HOSTS" DISTCC_DIR="/host/distcc" \
    ${PKGINST_ARCH+PKGINST_ARCH=$PKGINST_ARCH} ${PKGINST_CHECK_PKGS+PKGINST_CHECK_PKGS=$PKGINST_CHECK_PKGS} \
    CCACHE_DIR="/host/ccache" IN_CHROOT=1 LC_COLLATE=C LANG=en_US.UTF-8 TERM=linux HOME="/tmp" \
    PS1="[\u@$PKGINST_MASTERDIR \W]$ " /bin/bash +h
_EOF

    chmod 755 $PKGINST_MASTERDIR/bin/pkginst-shell

    cp -f /etc/resolv.conf $PKGINST_MASTERDIR/etc

    # Update pkginst alternative repository if set.
    mkdir -p $PKGINST_MASTERDIR/etc/pkginst.d
    if [ -n "$PKGINST_ALT_REPOSITORY" ]; then
        ( \
            echo "repository=/host/binpkgs/${PKGINST_ALT_REPOSITORY}"; \
            echo "repository=/host/binpkgs/${PKGINST_ALT_REPOSITORY}/nonfree"; \
            echo "repository=/host/binpkgs/${PKGINST_ALT_REPOSITORY}/debug"; \
            ) > $PKGINST_MASTERDIR/etc/pkginst.d/00-repository-alternative.conf
        if [ "$PKGINST_MACHINE" = "x86_64" ]; then
            ( \
                echo "repository=/host/binpkgs/${PKGINST_ALT_REPOSITORY}/multilib"; \
                echo "repository=/host/binpkgs/${PKGINST_ALT_REPOSITORY}/multilib/nonfree"; \
            ) >> $PKGINST_MASTERDIR/etc/pkginst.d/00-repository-alternative.conf
        fi
    else
        rm -f $PKGINST_MASTERDIR/etc/pkginst.d/00-repository-alternative.conf
    fi
}

chroot_prepare() {
    local f=

    if [ -f $PKGINST_MASTERDIR/.pkginst_chroot_init ]; then
        return 0
    elif [ ! -f $PKGINST_MASTERDIR/bin/bash ]; then
        msg_error "Bootstrap not installed in $PKGINST_MASTERDIR, can't continue.\n"
    fi

    # Create some required files.
    if [ -f /etc/localtime ]; then
        cp -f /etc/localtime $PKGINST_MASTERDIR/etc
    elif [ -f /usr/share/zoneinfo/UTC ]; then
        cp -f /usr/share/zoneinfo/UTC $PKGINST_MASTERDIR/etc/localtime
    fi

    for f in dev sys proc host boot; do
        [ ! -d $PKGINST_MASTERDIR/$f ] && mkdir -p $PKGINST_MASTERDIR/$f
    done

    # Copy /etc/passwd and /etc/group from base-files.
    cp -f $PKGINST_SRCPKGDIR/base-files/files/passwd $PKGINST_MASTERDIR/etc
    echo "$(whoami):x:$(id -u):$(id -g):$(whoami) user:/tmp:/bin/pkginst-shell" \
        >> $PKGINST_MASTERDIR/etc/passwd
    cp -f $PKGINST_SRCPKGDIR/base-files/files/group $PKGINST_MASTERDIR/etc
    echo "$(whoami):x:$(id -g):" >> $PKGINST_MASTERDIR/etc/group

    # Copy /etc/hosts from base-files.
    cp -f $PKGINST_SRCPKGDIR/base-files/files/hosts $PKGINST_MASTERDIR/etc

    mkdir -p $PKGINST_MASTERDIR/etc/pkginst.d
    echo "syslog=false" >> $PKGINST_MASTERDIR/etc/pkginst.d/pkginst.conf
    echo "cachedir=/host/repocache" >> $PKGINST_MASTERDIR/etc/pkginst.d/pkginst.conf
    ln -sf /dev/null $PKGINST_MASTERDIR/etc/pkginst.d/00-repository-main.conf

    # Prepare default locale: en_US.UTF-8.
    if [ -s ${PKGINST_MASTERDIR}/etc/default/libc-locales ]; then
        echo 'en_US.UTF-8 UTF-8' >> ${PKGINST_MASTERDIR}/etc/default/libc-locales
    fi

    touch -f $PKGINST_MASTERDIR/.pkginst_chroot_init
    [ -n "$1" ] && echo $1 >> $PKGINST_MASTERDIR/.pkginst_chroot_init

    return 0
}

chroot_sync_repos() {
    local f=

    # Copy pkginst configuration files to the masterdir.
    install -Dm644 ${PKGINST_DISTDIR}/etc/pkginst.conf \
        ${PKGINST_MASTERDIR}/etc/pkginst.d/00-pkginst-src.conf
    install -Dm644 ${PKGINST_DISTDIR}/etc/repos-local.conf \
        ${PKGINST_MASTERDIR}/etc/pkginst.d/10-repository-local.conf
    install -Dm644 ${PKGINST_DISTDIR}/etc/repos-remote.conf \
        ${PKGINST_MASTERDIR}/etc/pkginst.d/20-repository-remote.conf

    if [ "$PKGINST_MACHINE" = "x86_64" ]; then
        install -Dm644 ${PKGINST_DISTDIR}/etc/repos-local-x86_64.conf \
            ${PKGINST_MASTERDIR}/etc/pkginst.d/12-repository-local-x86_64.conf
        install -Dm644 ${PKGINST_DISTDIR}/etc/repos-remote-x86_64.conf \
            ${PKGINST_MASTERDIR}/etc/pkginst.d/22-repository-remote-x86_64.conf
    fi

    # if -N is set, get rid of remote repos from x86_64 (glibc).
    if [ -n "$PKGINST_SKIP_REMOTEREPOS" ]; then
        rm -f ${PKGINST_MASTERDIR}/etc/pkginst.d/20-repository-remote.conf
        rm -f ${PKGINST_MASTERDIR}/etc/pkginst.d/22-repository-remote-x86_64.conf
    fi

    # Copy host repos to the cross root.
    if [ -n "$PKGINST_CROSS_BUILD" ]; then
        rm -rf $PKGINST_MASTERDIR/$PKGINST_CROSS_BASE/etc/pkginst.d
        mkdir -p $PKGINST_MASTERDIR/$PKGINST_CROSS_BASE/etc/pkginst.d
        cp ${PKGINST_MASTERDIR}/etc/pkginst.d/*.conf \
            $PKGINST_MASTERDIR/$PKGINST_CROSS_BASE/etc/pkginst.d
        rm -f $PKGINST_MASTERDIR/$PKGINST_CROSS_BASE/etc/pkginst.d/*-x86_64.conf
    fi

    if [ -z "$PKGINST_SKIP_REMOTEREPOS" ]; then
        # Make sure to sync index for remote repositories.
        pkginst-install -r $PKGINST_MASTERDIR -S
    fi

    if [ -n "$PKGINST_CROSS_BUILD" ]; then
        # Copy host keys to the target rootdir.
        mkdir -p $PKGINST_MASTERDIR/$PKGINST_CROSS_BASE/var/db/pkginst/keys
        cp $PKGINST_MASTERDIR/var/db/pkginst/keys/*.plist \
            $PKGINST_MASTERDIR/$PKGINST_CROSS_BASE/var/db/pkginst/keys
        # Make sure to sync index for remote repositories.
        if [ -z "$PKGINST_SKIP_REMOTEREPOS" ]; then
            env -- PKGINST_TARGET_ARCH=$PKGINST_TARGET_MACHINE \
                pkginst-install -r $PKGINST_MASTERDIR/$PKGINST_CROSS_BASE -S
        fi
    fi

    return 0
}

chroot_handler() {
    local action="$1" pkg="$2" rv=0 arg= _envargs=

    if [ -n "$IN_CHROOT" -o -z "$CHROOT_READY" ]; then
        return 0
    fi
    if [ ! -d $PKGINST_MASTERDIR/plan10-packages ]; then
        mkdir -p $PKGINST_MASTERDIR/plan10-packages
    fi

    [ -z "$action" -a -z "$pkg" ] && return 1

    case "$action" in
        fetch|extract|patch|configure|build|check|install|pkg|bootstrap-update|chroot)
            chroot_prepare || return $?
            chroot_init || return $?
            chroot_sync_repos || return $?
            ;;
    esac

    if [ "$action" = "chroot" ]; then
        $PKGINST_COMMONDIR/chroot-style/${PKGINST_CHROOT_CMD:=uunshare}.sh \
            $PKGINST_MASTERDIR $PKGINST_DISTDIR "$PKGINST_HOSTDIR" "$PKGINST_CHROOT_CMD_ARGS" /bin/pkginst-shell
        rv=$?
    else
        env -i -- PATH="/usr/bin:$PATH" SHELL=/bin/sh \
            HOME=/tmp IN_CHROOT=1 LC_COLLATE=C LANG=en_US.UTF-8 \
            SOURCE_DATE_EPOCH="$SOURCE_DATE_EPOCH" \
            PKGINST_ALLOW_CHROOT_BREAKOUT="$PKGINST_ALLOW_CHROOT_BREAKOUT" \
            $PKGINST_COMMONDIR/chroot-style/${PKGINST_CHROOT_CMD:=uunshare}.sh \
            $PKGINST_MASTERDIR $PKGINST_DISTDIR "$PKGINST_HOSTDIR" "$PKGINST_CHROOT_CMD_ARGS" \
            /plan10-packages/pkginst-src $PKGINST_OPTIONS $action $pkg
        rv=$?
    fi

    return $rv
}
