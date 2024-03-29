#!/bin/bash
#
# vim: set ts=4 sw=4 et:
#
# Passed arguments:
#	$1 - pkgname [REQUIRED]
#	$2 - cross target [OPTIONAL]

if [ $# -lt 1 -o $# -gt 2 ]; then
    echo "${0##*/}: invalid number of arguments: pkgname [cross-target]"
    exit 1
fi

PKGNAME="$1"
PKGINST_CROSS_BUILD="$2"

for f in $PKGINST_SHUTILSDIR/*.sh; do
    . $f
done

setup_pkg "$PKGNAME" $PKGINST_CROSS_BUILD

for f in $PKGINST_COMMONDIR/environment/extract/*.sh; do
    source_file "$f"
done

PKGINST_EXTRACT_DONE="${PKGINST_STATEDIR}/${sourcepkg}_${PKGINST_CROSS_BUILD}_extract_done"

if [ -f $PKGINST_EXTRACT_DONE ]; then
    exit 0
fi

# Run pre-extract hooks
run_pkg_hooks pre-extract

# If template defines pre_extract(), use it.
if declare -f pre_extract >/dev/null; then
    run_func pre_extract
fi

# If template defines do_extract() use it rather than the hooks.
if declare -f do_extract >/dev/null; then
    [ ! -d "$wrksrc" ] && mkdir -p $wrksrc
    cd "$wrksrc"
    run_func do_extract
else
    if [ -n "$build_style" ]; then
        if [ ! -r $PKGINST_BUILDSTYLEDIR/${build_style}.sh ]; then
            msg_error "$pkgver: cannot find build helper $PKGINST_BUILDSTYLEDIR/${build_style}.sh!\n"
        fi
        . $PKGINST_BUILDSTYLEDIR/${build_style}.sh
    fi
    # If the build_style script declares do_extract(), use it rather than hooks.
    if declare -f do_extract >/dev/null; then
        run_func do_extract
    else
        # Run do-extract hooks
        run_pkg_hooks "do-extract"
    fi
fi


[ -d "$wrksrc" ] && cd "$wrksrc"

# If template defines post_extract(), use it.
if declare -f post_extract >/dev/null; then
    run_func post_extract
fi

# Run post-extract hooks
run_pkg_hooks post-extract

touch -f $PKGINST_EXTRACT_DONE

exit 0
