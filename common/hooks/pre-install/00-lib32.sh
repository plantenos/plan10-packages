# This hook creates the /usr/lib32 symlink for x86.

hook() {
	if [ "$PKGINST_TARGET_MACHINE" = "i686" ]; then
		vmkdir usr/lib
		ln -sf lib ${PKGDESTDIR}/usr/lib32
	fi
}
