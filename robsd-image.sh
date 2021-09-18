. "${EXECDIR}/util.sh"

DESTDIR="${DESTDIR}/src"
RELDIR="$(release_dir "$BUILDDIR")"; export RELDIR
RELXDIR="$(release_dir -x "$BUILDDIR")"; export RELXDIR

cd "${BSDSRCDIR}/distrib/$(machine)/iso"
make
make install
