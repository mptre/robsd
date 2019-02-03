. "${EXECDIR}/util.sh"

cleandir "$DESTDIR"
chown build "$DESTDIR"
chmod 700 "$DESTDIR"

DESTDIR="${DESTDIR}/src"
mkdir -p "$DESTDIR"

mkdir -p "$RELEASEDIR"
chown build "$RELEASEDIR"
chmod 755 "$RELEASEDIR"
# Wipe release directory in case of resuming.
cleandir "$RELEASEDIR"

cd "${BSDSRCDIR}/etc"
make release
