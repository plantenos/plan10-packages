hostmakedepends+=" go"
nostrip=yes
nopie=yes

case "$PKGINST_TARGET_MACHINE" in
	aarch64*) export GOARCH=arm64;;
	armv6*) export GOARCH=arm; export GOARM=6;;
	armv7*) export GOARCH=arm; export GOARM=7;;
	i686*) export GOARCH=386;;
	x86_64*) export GOARCH=amd64;;
	ppc64le*) export GOARCH=ppc64le;;
	ppc64*) export GOARCH=ppc64;;
esac

export GOPATH="${wrksrc}/_build-${pkgname}-pkginst"
GOSRCPATH="${GOPATH}/src/${go_import_path}"
export CGO_CFLAGS="$CFLAGS"
export CGO_CPPFLAGS="$CPPFLAGS"
export CGO_CXXFLAGS="$CXXFLAGS"
export CGO_LDFLAGS="$LDFLAGS"
export CGO_ENABLED=1
case "$PKGINST_TARGET_MACHINE" in
	*-musl) export GOCACHE="${PKGINST_HOSTDIR}/gocache-muslc" ;;
	*)	export GOCACHE="${PKGINST_HOSTDIR}/gocache-glibc" ;;
esac
