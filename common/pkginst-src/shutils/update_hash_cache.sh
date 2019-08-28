# vim: set ts=4 sw=4 et:

update_hash_cache() {
    local cache="$PKGINST_SRCDISTDIR/by_sha256"
    local distfile curfile
    mkdir -p "$cache"
    find "$PKGINST_SRCDISTDIR" -type f | grep -v by_sha256 | while read -r distfile; do
        cksum=$($PKGINST_DIGEST_CMD "$distfile")
        curfile="${distfile##*/}"
        ln -vf "$distfile" "${cache}/${cksum}_${curfile}"
    done
}
