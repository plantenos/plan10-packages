PKGINST_TARGET_CFLAGS="-mcpu=powerpc64le -mtune=power9 -maltivec -mlong-double-64 -mabi=elfv2"
PKGINST_TARGET_CXXFLAGS="$PKGINST_TARGET_CFLAGS"
PKGINST_TARGET_FFLAGS=""
PKGINST_TRIPLET="powerpc64le-unknown-linux-musl"
PKGINST_RUST_TARGET="$PKGINST_TRIPLET"