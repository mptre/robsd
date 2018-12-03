[ -d "$RELEASEDIR" ] || exit 1

DESTDIR="${DESTDIR}/xenocara"
mkdir -p "$DESTDIR"
rm -rf $DESTDIR/* $DESTDIR/.*

# Not suitable for parallelism.
unset MAKEFLAGS
cd "$X11SRCDIR"
make release
make checkdist
