# vim: set ts=4 sw=4 et:

run_func() {
    local func="$1" desc="$2" funcname="$3" restoretrap= logpipe= logfile= teepid=

    : ${funcname:=$func}

    logpipe=$(mktemp -u -p ${PKGINST_STATEDIR} ${pkgname}_${PKGINST_CROSS_BUILD}_XXXXXXXX.logpipe) || exit 1
    logfile=${PKGINST_STATEDIR}/${pkgname}_${PKGINST_CROSS_BUILD}_${funcname}.log

    msg_normal "${pkgver:-pkginst-src}: running ${desc:-${func}} ...\n"

    set -E
    restoretrap=$(trap -p ERR)
    trap 'error_func $funcname $LINENO' ERR

    mkfifo "$logpipe"
    tee "$logfile" < "$logpipe" &
    teepid=$!

    $func &>"$logpipe"

    wait $teepid
    rm "$logpipe"

    eval "$restoretrap"
    set +E
}

ch_wrksrc() {
  cd "$wrksrc" || msg_error "$pkgver: cannot access wrksrc directory [$wrksrc]\n"
  if [ -n "$build_wrksrc" ]; then
    cd $build_wrksrc || \
        msg_error "$pkgver: cannot access build_wrksrc directory [$build_wrksrc]\n"
  fi
}

# runs {pre,do,post}_X tripplets
run_step() {
  local step_name="$1" optional_step="$2" skip_post_hook="$3"

  ch_wrksrc
  run_pkg_hooks "pre-$step_name"

  # Run pre_* Phase
  if declare -f "pre_$step_name" >/dev/null; then
    ch_wrksrc
    run_func "pre_$step_name"
  fi

  ch_wrksrc
  # Run do_* Phase
  if declare -f "do_$step_name" >/dev/null; then
    run_func "do_$step_name"
  elif [ -n "$build_style" ]; then
    if [ -r $PKGINST_BUILDSTYLEDIR/${build_style}.sh ]; then
      . $PKGINST_BUILDSTYLEDIR/${build_style}.sh
      if declare -f "do_$step_name" >/dev/null; then
        run_func "do_$step_name"
      elif [ ! "$optional_step" ]; then
        msg_error "$pkgver: cannot find do_$step_name() in $PKGINST_BUILDSTYLEDIR/${build_style}.sh!\n"
      fi
    else
      msg_error "$pkgver: cannot find build helper $PKGINST_BUILDSTYLEDIR/${build_style}.sh!\n"
    fi
  elif [ ! "$optional_step" ]; then
    msg_error "$pkgver: cannot find do_$step_name()!\n"
  fi

  # Run do_ phase hooks
  run_pkg_hooks "do-$step_name"

  # Run post_* Phase
  if declare -f "post_$step_name" >/dev/null; then
    ch_wrksrc
    run_func "post_$step_name"
  fi

  if ! [ "$skip_post_hook" ]; then
    ch_wrksrc
    run_pkg_hooks "post-$step_name"
  fi
}

error_func() {
    local err=$?
    local src=
    local i=
    [ -n "$1" -a -n "$2" ] || exit 1;

    msg_red "$pkgver: $1: '${BASH_COMMAND}' exited with $err\n"
    for ((i=1;i<${#FUNCNAME[@]};i++)); do
        src=${BASH_SOURCE[$i]}
        src=${src#$PKGINST_DISTDIR/}
        msg_red "  in ${FUNCNAME[$i]}() at $src:${BASH_LINENO[$i-1]}\n"
        [ "${FUNCNAME[$i]}" = "$1" ] && break;
    done
    exit 1
}

exit_and_cleanup() {
    local rval=$1

    if [ -n "$PKGINST_TEMP_MASTERDIR" -a "$PKGINST_TEMP_MASTERDIR" != "1" ]; then
        rm -rf "$PKGINST_TEMP_MASTERDIR"
    fi
    exit ${rval:=0}
}

msg_red() {
    # error messages in bold/red
    [ -n "$NOCOLORS" ] || printf >&2 "\033[1m\033[31m"
    printf >&2 "=> ERROR: $@"
    [ -n "$NOCOLORS" ] || printf >&2 "\033[m"
}

msg_red_nochroot() {
    [ -n "$NOCOLORS" ] || printf >&2 "\033[1m\033[31m"
    printf >&2 "$@"
    [ -n "$NOCOLORS" ] || printf >&2 "\033[m"
}

msg_error() {
    msg_red "$@"
    [ -n "$PKGINST_INFORMATIVE_RUN" ] || exit 1
}

msg_warn() {
    # warn messages in bold/yellow
    [ -n "$NOCOLORS" ] || printf >&2 "\033[1m\033[33m"
    printf >&2 "=> WARNING: $@"
    [ -n "$NOCOLORS" ] || printf >&2  "\033[m"
}

msg_warn_nochroot() {
    [ -n "$NOCOLORS" ] || printf >&2 "\033[1m\033[33m"
    printf >&2 "=> WARNING: $@"
    [ -n "$NOCOLORS" ] || printf >&2 "\033[m"
}

msg_normal() {
    if [ -z "$PKGINST_QUIET" ]; then
        # normal messages in bold
        [ -n "$NOCOLORS" ] || printf "\033[1m"
        printf "=> $@"
        [ -n "$NOCOLORS" ] || printf "\033[m"
    fi
}

msg_normal_append() {
    [ -n "$NOCOLORS" ] || printf "\033[1m"
    printf "$@"
    [ -n "$NOCOLORS" ] || printf "\033[m"
}

set_build_options() {
    local f j pkgopts _pkgname
    local -A options

    if [ -z "$build_options" ]; then
        return 0
    fi

    for f in ${build_options}; do
        _pkgname=${pkgname//\-/\_}
        _pkgname=${_pkgname//\+/\_}
        eval pkgopts="\$PKGINST_PKG_OPTIONS_${_pkgname}"
        if [ -z "$pkgopts" -o "$pkgopts" = "" ]; then
            pkgopts=${PKGINST_PKG_OPTIONS}
        fi
        OIFS="$IFS"; IFS=','
        for j in ${pkgopts}; do
            case "$j" in
            "$f") options[$j]=1 ;;
            "~$f") options[${j#\~}]=0 ;;
            esac
        done
        IFS="$OIFS"
    done

    for f in ${build_options_default}; do
        [[ -z "${options[$f]}" ]] && options[$f]=1
    done

    # Prepare final options.
    for f in ${!options[@]}; do
        if [[ ${options[$f]} -eq 1 ]]; then
            eval export build_option_${f}=1
        else
            eval unset build_option_${f}
        fi
    done

    # Re-read pkg template to get conditional vars.
    if [ -z "$PKGINST_BUILD_OPTIONS_PARSED" ]; then
        source_file $PKGINST_SRCPKGDIR/$pkgname/template
        PKGINST_BUILD_OPTIONS_PARSED=1
        unset PKG_BUILD_OPTIONS
        set_build_options
        unset PKGINST_BUILD_OPTIONS_PARSED
        return 0
    fi

    # Sort pkg build options alphabetically.
    export PKG_BUILD_OPTIONS=$(
        for f in ${build_options}; do
            [[ "${options[$f]}" -eq 1 ]] || printf '~'
            printf '%s\n' "$f"
        done | sort
    )
}

source_file() {
    local f="$1"

    if [ ! -f "$f" -o ! -r "$f" ]; then
        return 0
    fi
    if ! source "$f"; then
        msg_error "pkginst-src: failed to read $f!\n"
    fi
}

run_pkg_hooks() {
    local phase="$1" hookn f

    eval unset -f hook
    for f in ${PKGINST_COMMONDIR}/hooks/${phase}/*.sh; do
        [ ! -r $f ] && continue
        hookn=${f##*/}
        hookn=${hookn%.sh}
        . $f
        run_func hook "$phase hook: $hookn" ${phase}_${hookn}
    done
}

unset_package_funcs() {
    local f

    for f in "$(typeset -F)"; do
        case "$f" in
        *_package)
            unset -f "$f"
            ;;
        esac
    done
}

get_endian() {
    local arch="${1%-*}"

    case "$arch" in
        aarch64)  echo "le";;
        armv5tel) echo "le";;
        armv6l)   echo "le";;
        armv7l)   echo "le";;
        i686)     echo "le";;
        mipsel*)  echo "le";;
        mips*)    echo "be";;
        ppc64le)  echo "le";;
        ppc64)    echo "be";;
        ppc)      echo "be";;
        x86_64)   echo "le";;
    esac
}

get_libc() {
    local arch="${1%-*}"

    if [ "${arch}" = "$1" ]; then
        echo "glibc"
    else
        echo "${1#${arch}-}"
    fi
}

get_wordsize() {
    local arch="${1%-*}"

    case "$arch" in
        aarch64)  echo "64";;
        armv5tel) echo "32";;
        armv6l)   echo "32";;
        armv7l)   echo "32";;
        i686)     echo "32";;
        mipsel*)  echo "32";;
        mips*)    echo "32";;
        ppc64le)  echo "64";;
        ppc64)    echo "64";;
        ppc)      echo "32";;
        x86_64)   echo "64";;
    esac
}

get_subpkgs() {
    local f

    for f in $(typeset -F); do
        case "$f" in
        *_package)
            echo "${f%_package}"
            ;;
        esac
    done
}

setup_pkg() {
    local pkg="$1" cross="$2" show_problems="$3"
    local basepkg val _vars f dbgflags arch

    [ -z "$pkg" ] && return 1
    basepkg=${pkg%-32bit}

    # Start with a sane environment
    unset -v PKG_BUILD_OPTIONS PKGINST_CROSS_CFLAGS PKGINST_CROSS_CXXFLAGS PKGINST_CROSS_FFLAGS PKGINST_CROSS_CPPFLAGS PKGINST_CROSS_LDFLAGS PKGINST_TARGET_QEMU_MACHINE
    unset -v subpackages run_depends build_depends host_build_depends

    unset_package_funcs

    . $PKGINST_CONFIG_FILE 2>/dev/null

    if [ -n "$cross" ]; then
        source_file $PKGINST_CROSSPFDIR/${cross}.sh

        _vars="TARGET_MACHINE CROSS_TRIPLET CROSS_CFLAGS CROSS_CXXFLAGS TARGET_QEMU_MACHINE"
        for f in ${_vars}; do
            eval val="\$PKGINST_$f"
            if [ -z "$val" ]; then
                echo "ERROR: PKGINST_$f is not defined!"
                exit 1
            fi
        done

        export PKGINST_CROSS_BASE=/usr/$PKGINST_CROSS_TRIPLET
        export PKGINST_TARGET_QEMU_MACHINE

        PKGINST_INSTALL_XCMD="env PKGINST_TARGET_ARCH=$PKGINST_TARGET_MACHINE $PKGINST_INSTALL_CMD -c /host/repocache -r $PKGINST_CROSS_BASE"
        PKGINST_QUERY_XCMD="env PKGINST_TARGET_ARCH=$PKGINST_TARGET_MACHINE $PKGINST_QUERY_CMD -c /host/repocache -r $PKGINST_CROSS_BASE"
        PKGINST_RECONFIGURE_XCMD="env PKGINST_TARGET_ARCH=$PKGINST_TARGET_MACHINE $PKGINST_RECONFIGURE_CMD -r $PKGINST_CROSS_BASE"
        PKGINST_REMOVE_XCMD="env PKGINST_TARGET_ARCH=$PKGINST_TARGET_MACHINE $PKGINST_REMOVE_CMD -r $PKGINST_CROSS_BASE"
        PKGINST_RINDEX_XCMD="env PKGINST_TARGET_ARCH=$PKGINST_TARGET_MACHINE $PKGINST_RINDEX_CMD"
        PKGINST_UHELPER_XCMD="env PKGINST_TARGET_ARCH=$PKGINST_TARGET_MACHINE pkginst-uhelper -r $PKGINST_CROSS_BASE"
        PKGINST_CHECKVERS_XCMD="env PKGINST_TARGET_ARCH=$PKGINST_TARGET_MACHINE pkginst-checkvers -r $PKGINST_CROSS_BASE --repository=$PKGINST_REPOSITORY"
    else
        export PKGINST_TARGET_MACHINE=${PKGINST_ARCH:-$PKGINST_MACHINE}
        unset PKGINST_CROSS_BASE PKGINST_CROSS_LDFLAGS PKGINST_CROSS_FFLAGS
        unset PKGINST_CROSS_CFLAGS PKGINST_CROSS_CXXFLAGS PKGINST_CROSS_CPPFLAGS
        unset PKGINST_CROSS_RUSTFLAGS PKGINST_CROSS_RUST_TARGET

        PKGINST_INSTALL_XCMD="$PKGINST_INSTALL_CMD"
        PKGINST_QUERY_XCMD="$PKGINST_QUERY_CMD"
        PKGINST_RECONFIGURE_XCMD="$PKGINST_RECONFIGURE_CMD"
        PKGINST_REMOVE_XCMD="$PKGINST_REMOVE_CMD"
        PKGINST_RINDEX_XCMD="$PKGINST_RINDEX_CMD"
        PKGINST_UHELPER_XCMD="$PKGINST_UHELPER_CMD"
        PKGINST_CHECKVERS_XCMD="$PKGINST_CHECKVERS_CMD"
    fi

    export PKGINST_ENDIAN=$(get_endian ${PKGINST_MACHINE})
    export PKGINST_TARGET_ENDIAN=$(get_endian ${PKGINST_TARGET_MACHINE})
    export PKGINST_LIBC=$(get_libc ${PKGINST_MACHINE})
    export PKGINST_TARGET_LIBC=$(get_libc ${PKGINST_TARGET_MACHINE})
    export PKGINST_WORDSIZE=$(get_wordsize ${PKGINST_MACHINE})
    export PKGINST_TARGET_WORDSIZE=$(get_wordsize ${PKGINST_TARGET_MACHINE})

    export PKGINST_INSTALL_XCMD PKGINST_QUERY_XCMD PKGINST_RECONFIGURE_XCMD \
        PKGINST_REMOVE_XCMD PKGINST_RINDEX_XCMD PKGINST_UHELPER_XCMD

    # Source all sourcepkg environment setup snippets.
    # Source all subpkg environment setup snippets.
    for f in ${PKGINST_COMMONDIR}/environment/setup-subpkg/*.sh; do
        source_file "$f"
    done
    for f in ${PKGINST_COMMONDIR}/environment/setup/*.sh; do
        source_file "$f"
    done

    if [ ! -f ${PKGINST_SRCPKGDIR}/${basepkg}/template ]; then
        msg_error "pkginst-src: unexistent file: ${PKGINST_SRCPKGDIR}/${basepkg}/template\n"
    fi
    if [ -n "$cross" ]; then
        export CROSS_BUILD="$cross"
        source_file ${PKGINST_SRCPKGDIR}/${basepkg}/template
    else
        unset CROSS_BUILD
        source_file ${PKGINST_SRCPKGDIR}/${basepkg}/template
    fi


    # Check if required vars weren't set.
    _vars="pkgname version short_desc revision homepage license"
    for f in ${_vars}; do
        eval val="\$$f"
        if [ -z "$val" -o -z "$f" ]; then
            msg_error "\"$f\" not set on $pkgname template.\n"
        fi
    done

    # Check if version is valid.
    case "$version" in
        *-*) msg_error "version contains invalid character: -\n";;
        *_*) msg_error "version contains invalid character: _\n";;
    esac
    case "$version" in
        *[0-9]*) : good ;;
        *) msg_error "version must contain at least one digit.\n";;
    esac

    # Check if base-chroot is already installed.
    if [ -z "$bootstrap" -a -z "$CHROOT_READY" -a "z$show_problems" != "zignore-problems" ]; then
        msg_red "${pkg} is not a bootstrap package and cannot be built without it.\n"
        msg_error "Please install bootstrap packages and try again.\n"
    fi

    sourcepkg="${pkgname}"
    if [ -z "$subpackages" ]; then
        subpackages="$(get_subpkgs)"
    fi

    if [ -h $PKGINST_SRCPKGDIR/$basepkg ]; then
        # Source all subpkg environment setup snippets.
        for f in ${PKGINST_COMMONDIR}/environment/setup-subpkg/*.sh; do
            source_file "$f"
        done
        pkgname=$pkg
        if ! declare -f ${basepkg}_package >/dev/null; then
            msg_error "$pkgname: missing ${basepkg}_package() function!\n"
        fi
    fi

    pkgver="${pkg}-${version}_${revision}"

    # If build_style() unset, a do_install() function must be defined.
    if [ -z "$build_style" ]; then
        # Check that at least do_install() is defined.
        if ! declare -f do_install >/dev/null; then
            msg_error "$pkgver: missing do_install() function!\n"
        fi
    fi

    FILESDIR=$PKGINST_SRCPKGDIR/$sourcepkg/files
    PATCHESDIR=$PKGINST_SRCPKGDIR/$sourcepkg/patches
    DESTDIR=$PKGINST_DESTDIR/$PKGINST_CROSS_TRIPLET/${sourcepkg}-${version}
    PKGDESTDIR=$PKGINST_DESTDIR/$PKGINST_CROSS_TRIPLET/${pkg}-${version}

    if [ -n "$disable_parallel_build" -o -z "$PKGINST_MAKEJOBS" ]; then
        PKGINST_MAKEJOBS=1
    fi
    makejobs="-j$PKGINST_MAKEJOBS"

    # strip whitespaces to make "  noarch  " valid too.
    if [ "${archs// /}" = "noarch" ]; then
        arch="noarch"
    else
        arch="$PKGINST_TARGET_MACHINE"
    fi
    if [ -n "$PKGINST_BINPKG_EXISTS" ]; then
        if [ "$($PKGINST_QUERY_XCMD -i -R -ppkgver $pkgver 2>/dev/null)" = "$pkgver" ]; then
            exit_and_cleanup
        fi
    fi

    if [ -z "$PKGINST_DEBUG_PKGS" -o "$repository" = "nonfree" ]; then
        nodebug=yes
    fi
    # -g is required to build -dbg packages.
    if [ -z "$nodebug" ]; then
        dbgflags="-g"
    fi

    # build profile is used always in order to expose the host triplet,
    # but the compiler flags from it are only used when not crossing
    if [ -z "$CHROOT_READY" ]; then
        source_file ${PKGINST_COMMONDIR}/build-profiles/bootstrap.sh
    else
        source_file ${PKGINST_COMMONDIR}/build-profiles/${PKGINST_MACHINE}.sh
    fi

    set_build_options

    export CFLAGS="$PKGINST_CFLAGS $PKGINST_CROSS_CFLAGS $CFLAGS $dbgflags"
    export CXXFLAGS="$PKGINST_CXXFLAGS $PKGINST_CROSS_CXXFLAGS $CXXFLAGS $dbgflags"
    export FFLAGS="$PKGINST_FFLAGS $PKGINST_CROSS_FFLAGS $FFLAGS"
    export CPPFLAGS="$PKGINST_CPPFLAGS $PKGINST_CROSS_CPPFLAGS $CPPFLAGS"
    export LDFLAGS="$PKGINST_LDFLAGS $PKGINST_CROSS_LDFLAGS $LDFLAGS"

    export BUILD_CC="cc"
    export BUILD_CXX="c++"
    export BUILD_CPP="cpp"
    export BUILD_FC="gfortran"
    export BUILD_LD="ld"
    export BUILD_CFLAGS="$PKGINST_CFLAGS"
    export BUILD_CXXFLAGS="$PKGINST_CXXFLAGS"
    export BUILD_CPPFLAGS="$PKGINST_CPPFLAGS"
    export BUILD_LDFLAGS="$PKGINST_LDFLAGS"
    export BUILD_FFLAGS="$PKGINST_FFLAGS"

    export CC_FOR_BUILD="cc"
    export CXX_FOR_BUILD="g++"
    export CPP_FOR_BUILD="cpp"
    export FC_FOR_BUILD="gfortran"
    export LD_FOR_BUILD="ld"
    export CFLAGS_FOR_BUILD="$PKGINST_CFLAGS"
    export CXXFLAGS_FOR_BUILD="$PKGINST_CXXFLAGS"
    export CPPFLAGS_FOR_BUILD="$PKGINST_CPPFLAGS"
    export LDFLAGS_FOR_BUILD="$PKGINST_LDFLAGS"
    export FFLAGS_FOR_BUILD="$PKGINST_FFLAGS"

    if [ -n "$cross" ]; then
        # Regular tools names
        export CC="${PKGINST_CROSS_TRIPLET}-gcc"
        export CXX="${PKGINST_CROSS_TRIPLET}-c++"
        export CPP="${PKGINST_CROSS_TRIPLET}-cpp"
        export FC="${PKGINST_CROSS_TRIPLET}-gfortran"
        export GCC="$CC"
        export LD="${PKGINST_CROSS_TRIPLET}-ld"
        export AR="${PKGINST_CROSS_TRIPLET}-ar"
        export AS="${PKGINST_CROSS_TRIPLET}-as"
        export RANLIB="${PKGINST_CROSS_TRIPLET}-ranlib"
        export STRIP="${PKGINST_CROSS_TRIPLET}-strip"
        export OBJDUMP="${PKGINST_CROSS_TRIPLET}-objdump"
        export OBJCOPY="${PKGINST_CROSS_TRIPLET}-objcopy"
        export NM="${PKGINST_CROSS_TRIPLET}-nm"
        export READELF="${PKGINST_CROSS_TRIPLET}-readelf"
        # Target tools
        export CC_target="$CC"
        export CXX_target="$CXX"
        export CPP_target="$CPP"
        export GCC_target="$GCC"
        export FC_target="$FC"
        export LD_target="$LD"
        export AR_target="$AR"
        export AS_target="$AS"
        export RANLIB_target="$RANLIB"
        export STRIP_target="$STRIP"
        export OBJDUMP_target="$OBJDUMP"
        export OBJCOPY_target="$OBJCOPY"
        export NM_target="$NM"
        export READELF_target="$READELF"
        # Target flags
        export CFLAGS_target="$CFLAGS"
        export CXXFLAGS_target="$CXXFLAGS"
        export CPPFLAGS_target="$CPPFLAGS"
        export LDFLAGS_target="$LDFLAGS"
        # Host tools
        export CC_host="cc"
        export CXX_host="g++"
        export CPP_host="cpp"
        export GCC_host="$CC_host"
        export FC_host="gfortran"
        export LD_host="ld"
        export AR_host="ar"
        export AS_host="as"
        export RANLIB_host="ranlib"
        export STRIP_host="strip"
        export OBJDUMP_host="objdump"
        export OBJCOPY_host="objcopy"
        export NM_host="nm"
        export READELF_host="readelf"
        # Host flags
        export CFLAGS_host="$PKGINST_CFLAGS"
        export CXXFLAGS_host="$PKGINST_CXXFLAGS"
        export CPPFLAGS_host="$PKGINST_CPPFLAGS"
        export LDFLAGS_host="$PKGINST_LDFLAGS"
        # Rust flags which are passed to rustc
        export RUSTFLAGS="$PKGINST_CROSS_RUSTFLAGS"
        # Rust target, which differs from our triplets
        export RUST_TARGET="$PKGINST_CROSS_RUST_TARGET"
        # Rust build, which is the host system, may also differ
        export RUST_BUILD="$PKGINST_RUST_TARGET"
    else
        # Target flags from build-profile
        export CFLAGS="$PKGINST_TARGET_CFLAGS $CFLAGS"
        export CXXFLAGS="$PKGINST_TARGET_CXXFLAGS $CXXFLAGS"
        export FFLAGS="$PKGINST_TARGET_FFLAGS $FFLAGS"
        export CPPFLAGS="$PKGINST_TARGET_CPPFLAGS $CPPFLAGS"
        export LDFLAGS="$PKGINST_TARGET_LDFLAGS $LDFLAGS"
        # Tools
        export CC="cc"
        export CXX="g++"
        export CPP="cpp"
        export GCC="$CC"
        export FC="gfortran"
        export LD="ld"
        export AR="ar"
        export AS="as"
        export RANLIB="ranlib"
        export STRIP="strip"
        export OBJDUMP="objdump"
        export OBJCOPY="objcopy"
        export NM="nm"
        export READELF="readelf"
        export RUST_TARGET="$PKGINST_RUST_TARGET"
        export RUST_BUILD="$PKGINST_RUST_TARGET"
        # Unset cross evironment variables
        unset CC_target CXX_target CPP_target GCC_target FC_target LD_target AR_target AS_target
        unset RANLIB_target STRIP_target OBJDUMP_target OBJCOPY_target NM_target READELF_target
        unset CFLAGS_target CXXFLAGS_target CPPFLAGS_target LDFLAGS_target
        unset CC_host CXX_host CPP_host GCC_host FC_host LD_host AR_host AS_host
        unset RANLIB_host STRIP_host OBJDUMP_host OBJCOPY_host NM_host READELF_host
        unset CFLAGS_host CXXFLAGS_host CPPFLAGS_host LDFLAGS_host
        unset RUSTFLAGS
    fi

    # Setup some specific package vars.
    if [ -z "$wrksrc" ]; then
        wrksrc="$PKGINST_BUILDDIR/${sourcepkg}-${version}"
    else
        wrksrc="$PKGINST_BUILDDIR/$wrksrc"
    fi

    if [ "$cross" -a "$nocross" -a "$show_problems" != "ignore-problems" ]; then
        msg_red "$pkgver: cannot be cross compiled, exiting...\n"
        msg_red "$pkgver: $nocross\n"
        exit 2
    elif [ "$broken" -a "$show_problems" != "ignore-problems" ]; then
        msg_red "$pkgver: cannot be built, it's currently broken; see the build log:\n"
        msg_red "$pkgver: $broken\n"
        exit 2
    fi

    if [ -n "$restricted" -a -z "$PKGINST_ALLOW_RESTRICTED" -a "$show_problems" != "ignore-problems" ]; then
        msg_red "$pkgver: does not allow redistribution of sources/binaries (restricted license).\n"
        msg_red "If you really need this software, run 'echo PKGINST_ALLOW_RESTRICTED=yes >> etc/conf'\n"
        exit 2
    fi

    export PKGINST_STATEDIR="${PKGINST_BUILDDIR}/.pkginst-${sourcepkg}"
    export PKGINST_WRAPPERDIR="${PKGINST_STATEDIR}/wrappers"

    mkdir -p $PKGINST_STATEDIR $PKGINST_WRAPPERDIR

    source_file $PKGINST_COMMONDIR/environment/build-style/${build_style}.sh

    # Source all build-helper files that are defined
    for f in $build_helper; do
        if [ ! -r $PKGINST_BUILDHELPERDIR/${f}.sh ];  then
            msg_error "$pkgver: cannot find build helper $PKGINST_BUILDHELPERDIR/${f}.sh!\n"
        fi
        . $PKGINST_BUILDHELPERDIR/${f}.sh
    done
}
