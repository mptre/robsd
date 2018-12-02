rm -rf $DESTDIR/* $DESTDIR/.*
chown build "$DESTDIR"
chmod 700 "$DESTDIR"

DESTDIR="${DESTDIR}/src"
mkdir -p "$DESTDIR"

mkdir -p "$RELEASEDIR"
chown build "$RELEASEDIR"
chmod 755 "$RELEASEDIR"
rm -rf $RELEASEDIR/* $RELEASEDIR/.*

cd "${BSDSRCDIR}/etc"
make release

cd "${BSDSRCDIR}/distrib/sets"
sh checkflist || true
