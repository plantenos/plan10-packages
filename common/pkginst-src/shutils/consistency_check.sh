# vim: set ts=4 sw=4 et:

consistency_check_existing () {
    while IFS=" " read -r dep origname deplabel; do
        [ -f "$PKGINST_SRCPKGDIR/$dep/template" ] && continue
        case "$deplabel" in
            makedepends|hostmakedepends|checkdepends)
                msg_warn "unsatisfied $deplabel in $origname: $dep does not exist\n";
                ;;
            *) printf "%s %s %s\n" "$dep" "$origname" "$deplabel" ;;
        esac
    done
}

consistency_convert_pkgname () {
    local origname= pkgname version= revision=
    while IFS=" " read -r dep origname deplabel; do
        case "$deplabel" in
            makedepends|hostmakedepends|checkdepends)
                printf "%s %s %s\n" "$dep" "$origname" "$deplabel"
                continue
                ;;
        esac
        case "$dep" in
            *\<*|*\>*|*=*) 
                printf "%s %s %s\n" "$dep" "$origname" "$deplabel"
                continue
                ;;
        esac
        if pkgname=$(pkginst-uhelper getpkgname "$dep" 2> /dev/null) && \
            version=$(pkginst-uhelper getpkgversion "$dep" 2> /dev/null) && \
            revision=$(pkginst-uhelper getpkgrevision "$dep" 2> /dev/null); then
            printf "%s %s %s\n" "${pkgname}>=${version}_${revision}" "$origname" "$deplabel"
        else
            printf "%s %s %s\n" "$dep>=0" "$origname" "$deplabel"
        fi
    done
}

consistency_check_smart () {
    local pkgname= depdef= dep=
    while IFS=" " read -r depdef origname deplabel; do
        case "$deplabel" in
            makedepends|hostmakedepends|checkdepends)
                printf "%s %s %s\n" "$depdef" "$origname" "$deplabel"
                continue
                ;;
        esac

        dep=$(pkginst-uhelper getpkgdepname "$depdef")

        if [ ! -f "$PKGINST_SRCPKGDIR/$dep/template" ]; then
            msg_warn "unsatisfied $deplabel in $origname: $dep does not exist\n";
            continue
        fi
        (
            PKGINST_TARGET_PKG=$dep
            read_pkg
            pkginst-uhelper pkgmatch "$depdef" "${pkgname}-${version}_${revision}" && return
            msg_red "unsatisfied $deplabel in $origname: $dep is $version, but required is $depdef\n";
        )
    done
}

consistency_check() {
    local pkg= pkgname=
    for pkg in "$PKGINST_SRCPKGDIR"/*/template; do
        pkg=${pkg%/*}
        PKGINST_TARGET_PKG=${pkg##*/}
        (
            read_pkg
            [ "$depends" ] && printf "%s $pkgname depends\n" $depends
            [ "$conflicts" ] && printf "%s $pkgname conflicts\n" $conflicts
            [ -L "$PKGINST_SRCPKGDIR/$PKGINST_TARGET_PKG" ] && return
            [ "$makedepends" ] && printf "%s $pkgname makedepends\n" $makedepends
            [ "$hostmakedepends" ] && printf "%s $pkgname hostmakedepends\n" $hostmakedepends
            [ "$checkdepends" ] && printf "%s $pkgname checkdepends\n" $checkdepends
        )
    done | grep -v "^virtual?" | sed "s/^[^ ]*?//" | consistency_check_existing | \
        consistency_convert_pkgname | consistency_check_smart
}
