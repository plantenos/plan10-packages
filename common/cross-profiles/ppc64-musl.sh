# Cross build profile for ppc64 big-endian musl.

PKGINST_TARGET_MACHINE="ppc64-musl"
PKGINST_TARGET_QEMU_MACHINE="ppc64"
PKGINST_CROSS_TRIPLET="powerpc64-linux-musl"
PKGINST_CROSS_CFLAGS="-mcpu=970 -mtune=power9 -maltivec -mlong-double-64 -mabi=elfv2"
PKGINST_CROSS_CXXFLAGS="$PKGINST_CROSS_CFLAGS"
PKGINST_CROSS_FFLAGS=""
PKGINST_CROSS_RUSTFLAGS="--sysroot=${PKGINST_CROSS_BASE}/usr"
PKGINST_CROSS_RUST_TARGET="powerpc64-unknown-linux-musl"
