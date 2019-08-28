# Cross build profile for ARM EABI5 Hard Float and Musl libc.

PKGINST_TARGET_MACHINE="armv6l-musl"
PKGINST_TARGET_QEMU_MACHINE="arm"
PKGINST_CROSS_TRIPLET="arm-linux-musleabihf"
PKGINST_CROSS_CFLAGS="-march=armv6 -mfpu=vfp -mfloat-abi=hard"
PKGINST_CROSS_CXXFLAGS="$PKGINST_CROSS_CFLAGS"
PKGINST_CROSS_FFLAGS=""
PKGINST_CROSS_RUSTFLAGS="--sysroot=${PKGINST_CROSS_BASE}/usr"
PKGINST_CROSS_RUST_TARGET="arm-unknown-linux-musleabihf"
