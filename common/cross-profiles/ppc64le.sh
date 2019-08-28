# Cross build profile for ppc64 little-endian GNU.

PKGINST_TARGET_MACHINE="ppc64le"
PKGINST_TARGET_QEMU_MACHINE="ppc64le"
PKGINST_CROSS_TRIPLET="powerpc64le-linux-gnu"
PKGINST_CROSS_CFLAGS="-mcpu=powerpc64le -mtune=power9 -maltivec -mabi=elfv2"
PKGINST_CROSS_CXXFLAGS="$PKGINST_CROSS_CFLAGS"
PKGINST_CROSS_FFLAGS=""
PKGINST_CROSS_RUSTFLAGS="--sysroot=${PKGINST_CROSS_BASE}/usr"
PKGINST_CROSS_RUST_TARGET="powerpc64le-unknown-linux-gnu"
