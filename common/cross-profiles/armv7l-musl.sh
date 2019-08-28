# Cross build profile for ARMv7 EABI Hard Float and Musl libc.

PKGINST_TARGET_MACHINE="armv7l-musl"
PKGINST_TARGET_QEMU_MACHINE="arm"
PKGINST_CROSS_TRIPLET="armv7l-linux-musleabihf"
PKGINST_CROSS_CFLAGS="-march=armv7-a -mfpu=vfpv3 -mfloat-abi=hard"
PKGINST_CROSS_CXXFLAGS="$PKGINST_CROSS_CFLAGS"
PKGINST_CROSS_FFLAGS=""
PKGINST_CROSS_RUSTFLAGS="--sysroot=${PKGINST_CROSS_BASE}/usr"
PKGINST_CROSS_RUST_TARGET="armv7-unknown-linux-musleabihf"
