# Define equivalent of TOML config in environment
# [build]
# jobs = $PKGINST_MAKEJOBS
export CARGO_BUILD_JOBS="$PKGINST_MAKEJOBS"

if [ "$CROSS_BUILD" ]; then
	# Define equivalent of TOML config in environment
	# [target.${RUST_TARGET}]
	# linker = ${CC}
	_PKGINST_CROSS_RUST_TARGET_ENV="${PKGINST_CROSS_RUST_TARGET^^}"
	_PKGINST_CROSS_RUST_TARGET_ENV="${_PKGINST_CROSS_RUST_TARGET_ENV//-/_}"
	export CARGO_TARGET_${_PKGINST_CROSS_RUST_TARGET_ENV}_LINKER="$CC"
	unset _PKGINST_CROSS_RUST_TARGET_ENV
	
	# Define equivalent of TOML config in environment
	# [build]
	# target = ${RUST_TARGET}
	export CARGO_BUILD_TARGET="$RUST_TARGET"
else
	unset CARGO_BUILD_TARGET
fi

# For cross-compiling rust -sys crates
export PKG_CONFIG_ALLOW_CROSS=1

# libgit2-sys
export LIBGIT2_SYS_USE_PKG_CONFIG=1

# gettext-rs
export GETTEXT_BIN_DIR=/usr/bin
export GETTEXT_LIB_DIR="${PKGINST_CROSS_BASE}/usr/lib/gettext"
export GETTEXT_INCLUDE_DIR="${PKGINST_CROSS_BASE}/usr/include"

# libssh2-sys
export LIBSSH2_SYS_USE_PKG_CONFIG=1 

# sodium-sys
export SODIUM_LIB_DIR="${PKGINST_CROSS_BASE}/usr/include"
export SODIUM_INC_DIR="${PKGINST_CROSS_BASE}/usr/lib"
