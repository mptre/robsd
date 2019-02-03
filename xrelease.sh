. "${EXECDIR}/util.sh"

[ -d "$RELEASEDIR" ] || exit 1

DESTDIR="${DESTDIR}/xenocara"
mkdir -p "$DESTDIR"
cleandir "$DESTDIR"

# Not suitable for parallelism.
unset MAKEFLAGS
cd "$X11SRCDIR"
make release
make checkdist
