chown build "$DESTDIR"
chmod 700 "$DESTDIR"
rm -rf $DESTDIR/* $DESTDIR/.*

mkdir -p "$RELEASEDIR"
chown build "$RELEASEDIR"
chmod 755 "$RELEASEDIR"
rm -rf $RELEASEDIR/* $RELEASEDIR/.*

cd "${BSDSRCDIR}/etc"
make release

cd "${BSDSRCDIR}/distrib/sets"
sh checkflist
