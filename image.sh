DESTDIR="${DESTDIR}/src"
[ -e "$DESTDIR" ] || exit 1

RELDIR="$RELEASEDIR"; export RELDIR
RELXDIR="$RELEASEDIR"; export RELXDIR

cd "${BSDSRCDIR}/distrib/$(machine)/iso"
# Not suitable for parallelism.
unset MAKEFLAGS
make
make install
