. "${EXECDIR}/util.sh"

DESTDIR="${DESTDIR}/xenocara"
mkdir -p "$DESTDIR"
cleandir "$DESTDIR"
chown build "$DESTDIR"
chmod 700 "$DESTDIR"

RELEASEDIR="$(release_dir -x "$LOGDIR")"; export RELEASEDIR
mkdir -p "$RELEASEDIR"
cleandir "$RELEASEDIR"
chown build "$RELEASEDIR"
chmod 755 "$RELEASEDIR"

# Not suitable for parallelism.
unset MAKEFLAGS
cd "$XSRCDIR"
make release
make checkdist
