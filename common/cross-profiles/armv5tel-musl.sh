# Cross build profile for ARM GNU EABI5 Soft Float and Musl libc.

PKGINST_TARGET_MACHINE="armv5tel-musl"
PKGINST_TARGET_QEMU_MACHINE="arm"
PKGINST_CROSS_TRIPLET="arm-linux-musleabi"
PKGINST_CROSS_CFLAGS="-march=armv5te -msoft-float -mfloat-abi=soft"
PKGINST_CROSS_CXXFLAGS="$PKGINST_CROSS_CFLAGS"
PKGINST_CROSS_FFLAGS=""