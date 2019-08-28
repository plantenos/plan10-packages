# Cross build profile for MIPS32 BE hard float.

PKGINST_TARGET_MACHINE="mipshf-musl"
PKGINST_TARGET_QEMU_MACHINE="mips"
PKGINST_CROSS_TRIPLET="mips-linux-muslhf"
PKGINST_CROSS_CFLAGS="-mtune=mips32r2 -mabi=32 -mhard-float"
PKGINST_CROSS_CXXFLAGS="$PKGINST_CROSS_CFLAGS"
PKGINST_CROSS_FFLAGS=""
PKGINST_CROSS_RUSTFLAGS="--sysroot=${PKGINST_CROSS_BASE}/usr"
PKGINST_CROSS_RUST_TARGET="mips-unknown-linux-musl"
