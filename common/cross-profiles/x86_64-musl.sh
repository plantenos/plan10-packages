# Cross build profile for x86_64 and Musl libc.

PKGINST_TARGET_MACHINE="x86_64-musl"
PKGINST_TARGET_QEMU_MACHINE="x86_64"
PKGINST_CROSS_TRIPLET="x86_64-linux-musl"
PKGINST_CROSS_CFLAGS="-mtune=generic"
PKGINST_CROSS_CXXFLAGS="$PKGINST_CROSS_CFLAGS"
PKGINST_CROSS_FFLAGS=""
PKGINST_CROSS_RUSTFLAGS="--sysroot=${PKGINST_CROSS_BASE}/usr"
PKGINST_CROSS_RUST_TARGET="x86_64-unknown-linux-musl"
