. "${EXECDIR}/util.sh"

DESTDIR="${DESTDIR}/src"
RELDIR="$(release_dir "$LOGDIR")"; export RELDIR
RELXDIR="$(release_dir -x "$LOGDIR")"; export RELXDIR

cd "${BSDSRCDIR}/distrib/$(machine)/iso"
make
make install
