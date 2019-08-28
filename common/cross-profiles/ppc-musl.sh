# Cross build profile for PowerPC.

PKGINST_TARGET_MACHINE="ppc-musl"
PKGINST_TARGET_QEMU_MACHINE="ppc"
PKGINST_CROSS_TRIPLET="powerpc-linux-musl"
PKGINST_CROSS_CFLAGS="-mcpu=powerpc -mno-altivec -mtune=G4 -mlong-double-64"
PKGINST_CROSS_CXXFLAGS="$PKGINST_CROSS_CFLAGS"
PKGINST_CROSS_FFLAGS=""
PKGINST_CROSS_RUSTFLAGS="--sysroot=${PKGINST_CROSS_BASE}/usr"
PKGINST_CROSS_RUST_TARGET="powerpc-unknown-linux-musl"
